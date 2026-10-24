import Foundation

/// One dive draft as the drafts list offers it: the server's as last read, with the phone's
/// own change laid over it while that waits, or one begun on the phone that has not landed.
public struct DiveDraftEntry: Hashable, Sendable, Identifiable {
  public var id: RecordRef { ref }
  /// The server's ref once it has landed; the phone's own until then.
  public let ref: RecordRef
  /// The draft's whole state as the phone has it.
  public let write: DiveDraftWrite
  /// When it last changed, here or on the server.
  public let changedAt: Date
  /// A change of the phone's is still to reach the server.
  public let hasPendingChange: Bool

  /// The cached server drafts, less any whose log or discard is queued and with any queued
  /// state over the server's, then the phone's own, the most recently changed first.
  static func list(cached: [DiveDraftRead], items: [OutboxItem]) -> [DiveDraftEntry] {
    var latest: [RecordRef: (DiveDraftWrite, Date)] = [:]
    var gone: Set<RecordRef> = []
    for item in items {
      switch item.operation {
      case .createDiveDraft(let write):
        if let ref = item.creates { latest[ref] = (write, item.changedAt) }
      case .updateDiveDraft(let ref, let write):
        latest[ref] = (write, item.changedAt)
      case .logDive(let ref, _), .deleteDiveDraft(let ref):
        gone.insert(ref)
      default:
        break
      }
    }
    var entries: [DiveDraftEntry] = []
    var listed: Set<RecordRef> = []
    for draft in cached {
      let ref = RecordRef.server(draft.uuid)
      guard !gone.contains(ref), listed.insert(ref).inserted else { continue }
      let mine = latest[ref]
      entries.append(
        DiveDraftEntry(
          ref: ref, write: mine?.0 ?? draft.write,
          changedAt: mine?.1 ?? draft.updatedAt.instant ?? .distantPast,
          hasPendingChange: mine != nil))
    }
    for item in items {
      guard case .createDiveDraft = item.operation, let ref = item.creates,
        !gone.contains(ref), let mine = latest[ref]
      else { continue }
      entries.append(
        DiveDraftEntry(ref: ref, write: mine.0, changedAt: mine.1, hasPendingChange: true))
    }
    return entries.sorted { $0.changedAt > $1.changedAt }
  }
}
