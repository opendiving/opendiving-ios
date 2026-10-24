import Foundation
import Observation

/// What one record sheet holds: the values being typed, the sentences under the fields once a
/// save has been tried, and — opened on a failed item — the server's sentence about it. Saving
/// queues the create, or re-queues the failed item under its key, and hands back the ref the
/// picker selects.
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

  @ObservationIgnored private let outbox: OutboxModel
  @ObservationIgnored private let failedItem: UUID?

  /// `values` is what the sheet opens on; with `failedItem` naming a queued write of this
  /// form's kind, its values replace them.
  public init(outbox: OutboxModel, values: Values, failedItem: UUID? = nil) {
    self.outbox = outbox
    self.values = values
    if let failedItem, let item = outbox.item(failedItem),
      let reopened = Values(reopening: item.operation)
    {
      self.values = reopened
      self.failedItem = failedItem
      failure = item.failure?.message ?? item.lastAnswer?.sentence
    } else {
      self.failedItem = nil
    }
  }

  /// Whether the sheet reopened a write already queued.
  public var isReopened: Bool { failedItem != nil }

  public var issues: [FormIssue] { attempted ? values.issues : [] }

  /// The sentence under one field, once a save has been tried.
  public func message(_ field: String, index: Int? = nil, member: String? = nil) -> String? {
    issues.first { $0.field == field && $0.index == index && $0.member == member }?.message
  }

  /// Queues the write, or re-queues the reopened one, and returns the record it names: the new
  /// record's local ref, or the set an update replaces. Nil when the form is not valid or the
  /// outbox refused it, with the reason on screen.
  public func save() -> RecordRef? {
    attempted = true
    saveError = nil
    let operation: OutboxOperation
    do {
      operation = try values.operation()
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
        try outbox.edit(failedItem, operation)
        return item.creates ?? operation.target
      }
      let item = try outbox.queue(operation)
      return item.creates ?? operation.target
    } catch {
      saveError = Self.sentence(error)
      return nil
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
