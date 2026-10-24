import Foundation

/// The edit drafts of one account: at most one per dive being edited, keyed by the dive's ref,
/// kept on the phone alone until the edit is saved. What a draft holds is its caller's; the
/// store knows only that it can rewrite the records it names.
///
/// Each draft is a file of its own under `Drafts/`, written atomically, and a file this build
/// cannot read is kept — listed by ``unreadable()``, never overwritten. A draft is read with
/// the queue's resolutions applied: a record whose create has landed is named by the server's
/// uuid, and one whose create was discarded is no longer named.
public struct DraftStore<Value: Codable & Sendable & RewritesLocalRefs>: Sendable {
  struct Envelope: Codable, Sendable {
    var ref: RecordRef
    var savedAt: Date
    var value: Value
  }

  public let account: UUID
  private let folder: KeptFolder<Envelope>
  private let outbox: OutboxStore

  public init(store: ServerStateStore, origin: ServerOrigin, account: UUID) {
    self.account = account
    folder = KeptFolder(
      url: store.directory(for: origin, account: account)
        .appendingPathComponent("Drafts", isDirectory: true))
    outbox = OutboxStore(store: store, origin: origin, account: account)
  }

  /// The store of the account the session names, or nil when there is none.
  @MainActor
  public init?(session: Session) {
    guard let stores = AccountStores.current(session) else { return nil }
    self.init(store: stores.store, origin: stores.origin, account: stores.account)
  }

  /// The draft of `ref`'s edit, or nil.
  public func load(_ ref: RecordRef) -> Value? {
    entries().first { $0.envelope.ref == outbox.resolved(ref) }?.envelope.value
  }

  /// Every draft, the most recently saved first.
  public func all() -> [(ref: RecordRef, value: Value)] {
    entries().sorted { $0.envelope.savedAt > $1.envelope.savedAt }
      .map { ($0.envelope.ref, $0.envelope.value) }
  }

  /// Writes `value` as the draft of `ref`'s edit, in place of the one it had.
  public func save(_ value: Value, for ref: RecordRef) throws {
    let ref = outbox.resolved(ref)
    let name =
      entries().first { $0.envelope.ref == ref }?.name
      ?? KeptFolder<Envelope>.name(for: UUID())
    try folder.write(Envelope(ref: ref, savedAt: Date(), value: value), name: name)
  }

  public func remove(_ ref: RecordRef) {
    let ref = outbox.resolved(ref)
    for entry in entries() where entry.envelope.ref == ref { folder.remove(entry.name) }
  }

  /// The draft files this build cannot read, by name.
  public func unreadable() -> [String] {
    folder.load().unreadable
  }

  /// *Discard* on a draft this build cannot read.
  public func removeUnreadable(_ name: String) {
    guard folder.contains(name), folder.read(name) == nil else { return }
    folder.remove(name)
  }

  /// The drafts, rewritten through the queue's resolutions and written back where that
  /// changed them.
  private func entries() -> [(name: String, envelope: Envelope)] {
    let resolutions = outbox.resolutions()
    let creating = Set(outbox.items().compactMap(\.creates))
    func rewrite(_ ref: RecordRef) -> RecordRef? {
      guard case .local(let local) = ref else { return ref }
      if let resolution = resolutions[local] {
        return resolution.server.map(RecordRef.server) ?? ref
      }
      return creating.contains(ref) ? ref : nil
    }
    return folder.load().values.map { entry in
      var envelope = entry.value
      let before = try? APICoding.encoder().encode(envelope)
      envelope.ref = rewrite(envelope.ref) ?? envelope.ref
      envelope.value.rewriteRefs(rewrite)
      if let before, before != (try? APICoding.encoder().encode(envelope)) {
        try? folder.write(envelope, name: entry.name)
      }
      return (entry.name, envelope)
    }
  }
}
