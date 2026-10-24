import Foundation

// Signed in before the account has loaded, the stores are the last account's and what is
// written to them is marked. The load settles the marks: the writes stay where they are when
// it names that account, and move to the loaded account's stores when it names another,
// since a live token's writes are its account's. Nothing marked is sent before then.
extension OutboxModel {
  func clearMarks(in outbox: OutboxStore) {
    for var item in outbox.items() where item.writtenBeforeAccountKnown {
      item.writtenBeforeAccountKnown = false
      try? outbox.save(item)
    }
  }

  /// The account `loaded` has loaded: its own marked writes stay, and every other account's
  /// move here. Each is written here before it is removed there, so an interruption leaves it
  /// twice rather than nowhere.
  func settleMarks(origin: ServerOrigin, loaded user: UserRead) {
    let mine = OutboxStore(store: session.store, origin: origin, account: user.uuid)
    mine.rememberAccountLabel(user)
    for other in OutboxStore.all(store: session.store, origin: origin)
    where other.account != user.uuid {
      move(from: other, to: mine)
    }
    clearMarks(in: mine)
  }

  /// A moved write keeps only the records written beside it, which move too: everything else
  /// it names is the other account's, and is left out. One about a record of the other
  /// account's has nothing here to change and fails, except a log, which carries the dive.
  private func move(from other: OutboxStore, to mine: OutboxStore) {
    let marked = other.items().filter(\.writtenBeforeAccountKnown)
    guard !marked.isEmpty else { return }
    let moving = Set(marked.compactMap(\.creates))
    let label = other.accountLabel().map { $0.name.isEmpty ? $0.username : $0.name }
    var sequence = mine.nextSequence()
    for item in marked {
      var moved = item
      moved.writtenBeforeAccountKnown = false
      moved.sequence = sequence
      sequence += 1
      let kinds = Dictionary(
        item.operation.namedRecords.map { ($0.ref, $0.kind) }, uniquingKeysWith: { a, _ in a })
      var dropped: [OutboxRecordKind] = []
      moved.operation.rewriteRefs { ref in
        guard !moving.contains(ref) else { return ref }
        if let kind = kinds[ref], !dropped.contains(kind) { dropped.append(kind) }
        return nil
      }
      moved.dropped = dropped
      if let target = item.operation.target, !moving.contains(target) {
        if case .logDive(_, let dive) = moved.operation {
          moved.operation = .createDive(dive)
        } else {
          moved.state = .failed(
            OutboxFailure(
              kind: .wrongAccount, message: OutboxText.writtenForAnotherAccount(label)))
        }
      }
      guard (try? mine.save(moved)) != nil else { continue }
      other.remove(item.id)
    }
  }
}
