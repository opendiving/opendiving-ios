import Foundation
import Observation

/// What one record form holds: the values being typed, the sentences under the fields once a
/// save has been tried, and — opened on a failed item — the server's sentence about it. Saving
/// queues the create, or re-queues the failed item under its key, and hands back the ref the
/// picker selects.
///
/// **Opened on a record the account has**, it edits instead: the values are the record with
/// its queued updates laid over, saving queues what differs from them, and ``delete()`` queues
/// the record's deletion.
@MainActor
@Observable
public final class RecordSheetModel<Values: RecordSheetValues> {
  public var values: Values
  /// The server's sentence about the failed item the sheet reopened.
  public private(set) var failure: String?
  /// Why the save did not queue, when the form itself was fine.
  public private(set) var saveError: String?
  /// Set by the first save, after which the sentences follow the values as they change, as
  /// the web's resolver does once a form has been submitted.
  public private(set) var attempted = false

  /// How the form writes the record it opened on.
  struct Editing {
    let ref: RecordRef
    /// Nil when the values still agree with what the form opened on.
    let write: (Values) throws -> OutboxOperation?
    let delete: OutboxOperation
  }

  @ObservationIgnored private let outbox: OutboxModel
  @ObservationIgnored private let failedItem: UUID?
  @ObservationIgnored private let editing: Editing?

  init(outbox: OutboxModel, values: Values, failed: OutboxItem?, editing: Editing?) {
    self.outbox = outbox
    self.values = values
    self.editing = editing
    failedItem = failed?.id
    failure = failed.flatMap { $0.failure?.message ?? $0.lastAnswer?.sentence }
  }

  /// `values` is what the sheet opens on; with `failedItem` naming a queued write of this
  /// form's kind, its values replace them.
  public convenience init(outbox: OutboxModel, values: Values, failedItem: UUID? = nil) {
    if let failedItem, let item = outbox.item(failedItem),
      let reopened = Values(reopening: item.operation)
    {
      self.init(outbox: outbox, values: reopened, failed: item, editing: nil)
    } else {
      self.init(outbox: outbox, values: values, failed: nil, editing: nil)
    }
  }

  /// Whether the form opened on what exists — a queued write, or a record — so its button saves
  /// changes rather than creates.
  public var isReopened: Bool { failedItem != nil || editing != nil }

  /// Whether the form is editing a record the account has.
  public var isEditing: Bool { editing != nil }

  /// Whether ``delete()`` is offered: on a record, and not over a refused edit of it, which the
  /// pending screen discards.
  public var canDelete: Bool { editing != nil && failedItem == nil }

  public var issues: [FormIssue] { attempted ? values.issues : [] }

  /// The sentence under one field, once a save has been tried.
  public func message(_ field: String, index: Int? = nil, member: String? = nil) -> String? {
    issues.first { $0.field == field && $0.index == index && $0.member == member }?.message
  }

  /// Queues the write, or re-queues the reopened one, and returns the record it names: the new
  /// record's local ref, or the record an update changes, even when nothing had changed to send.
  /// Nil when the form is not valid or the outbox refused it, with the reason on screen.
  public func save() -> RecordRef? {
    attempted = true
    saveError = nil
    let operation: OutboxOperation?
    do {
      operation = try editing.map { try $0.write(values) } ?? values.operation()
    } catch {
      return nil
    }
    do {
      if let failedItem {
        // Discarded from the pending screen while this was open: saving it would queue a
        // second record the diver already chose not to make.
        guard let item = outbox.item(failedItem) else {
          saveError = "This was discarded meanwhile, so nothing was saved."
          return nil
        }
        guard let operation else {
          outbox.discard(failedItem)
          return editing?.ref
        }
        try outbox.edit(failedItem, operation)
        return item.creates ?? operation.target
      }
      guard let operation else { return editing?.ref }
      let item = try outbox.queue(operation)
      return item.creates ?? operation.target
    } catch {
      saveError = Self.sentence(error)
      return nil
    }
  }

  /// Queues the deletion of the record the form opened on. False, with the reason on screen,
  /// when the outbox refused it.
  public func delete() -> Bool {
    guard canDelete, let editing else { return false }
    saveError = nil
    do {
      try outbox.queue(editing.delete)
      return true
    } catch {
      saveError = Self.sentence(error)
      return false
    }
  }

  static func sentence(_ error: any Error) -> String {
    switch error as? OutboxModel.OutboxError {
    case .noAccount:
      "Your account has not loaded yet, so this cannot be kept. Try again in a moment."
    case .notEditable:
      "This is being sent, or may already have reached the server, so it can no longer be changed."
    default:
      "This could not be saved on the phone. Try again."
    }
  }
}

extension RecordSheetModel where Values: RecordEditValues {
  /// Edits `ref`, read as `read`. `failedItem` names a queued update the server refused, whose
  /// changes the form opens with and which saving replaces.
  public convenience init(
    outbox: OutboxModel, editing ref: RecordRef, read: Values, failedItem: UUID? = nil
  ) {
    func laidOver(_ writes: [OutboxItem]) -> Values {
      writes.reduce(read) { $0.applying($1.operation) }
    }
    let writes = outbox.items.filter { $0.operation.target == ref }
    // The reopened write stays out of what the form compares against, whatever its state: in it,
    // saving would find none of that write's own changes to keep.
    let baseline = laidOver(writes.filter { !$0.isFailed && $0.id != failedItem })
    self.init(
      outbox: outbox, values: laidOver(writes.filter { !$0.isFailed || $0.id == failedItem }),
      failed: writes.first { $0.id == failedItem },
      editing: Editing(
        ref: ref, write: { try $0.update(of: ref, from: baseline) }, delete: Values.delete(ref)))
  }
}
