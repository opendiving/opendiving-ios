import Foundation

/// A write the server has not acknowledged, as the outbox keeps it: one file each, on disk
/// before the screen says it is queued.
public struct OutboxItem: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let queuedAt: Date
  /// When the diver last changed it: a draft's update replaced by a newer state, an edit.
  public var changedAt: Date
  /// The queue's order; earlier is sent first.
  public var sequence: Int
  public var operation: OutboxOperation
  /// The local ref of the record a create makes — for a log, the dive. Nil for an update or a
  /// delete.
  public var creates: RecordRef?
  /// Chosen when the item is queued and kept, so a retry is the same request.
  public let idempotencyKey: UUID
  public var state: OutboxItemState
  /// Whether the request has ever left the phone. An attempted create may have committed
  /// under its key, so its body is fixed and it cannot be withdrawn as never sent.
  public var attempted: Bool
  /// A create's exact bytes as first sent, every local ref already rewritten: every retry
  /// sends these, so the key can never meet a different body.
  public var sentBody: Data?
  /// Written while signed in before the account had loaded, into the stores of the account
  /// last loaded: it moves if the load names another account.
  public var writtenBeforeAccountKnown: Bool
  /// What a move between accounts' stores left out of it.
  public var dropped: [OutboxRecordKind]

  init(
    operation: OutboxOperation, sequence: Int, marked: Bool, now: Date = Date()
  ) {
    id = UUID()
    queuedAt = now
    changedAt = now
    self.sequence = sequence
    self.operation = operation
    switch operation {
    case .updateDive, .updateGearSet, .updateDiveDraft, .deleteDiveDraft: creates = nil
    default: creates = .local(UUID())
    }
    idempotencyKey = UUID()
    state = .pending(lastAnswer: nil)
    attempted = false
    sentBody = nil
    writtenBeforeAccountKnown = marked
    dropped = []
  }

  /// The record the item writes: the one a create makes, else its target. Writes to one
  /// record go in the order they were queued.
  public var record: RecordRef? {
    if case .logDive(let draft, _) = operation { return draft }
    return creates ?? operation.target
  }

  public var isFailed: Bool {
    if case .failed = state { true } else { false }
  }

  public var isPending: Bool {
    if case .pending = state { true } else { false }
  }

  /// The last answer recorded for a pending item.
  public var lastAnswer: OutboxAnswer? {
    if case .pending(let answer) = state { answer } else { nil }
  }

  public var failure: OutboxFailure? {
    if case .failed(let failure) = state { failure } else { nil }
  }

  /// Whether the pending screen offers *Edit*: any update; a create never sent, or one the
  /// server refused with a 4xx, which it holds nothing for. A create sent once and answered
  /// any other way may have committed under its key, so its body stays. A write moved from
  /// another account's stores has nothing to apply to here. Nothing is edited while it is
  /// being sent: the answer would overwrite the edit.
  public var isEditable: Bool {
    if state == .inFlight || failure?.kind == .wrongAccount { return false }
    switch operation {
    case .updateDive, .updateGearSet, .updateDiveDraft: return true
    case .deleteDiveDraft: return false
    default: return !attempted || failure?.kind == .refused
    }
  }
}

extension OutboxItem {
  /// Whether the pending screen offers *Discard*: any item but the one being sent, whose answer
  /// is on its way.
  public var isDiscardable: Bool { state != .inFlight }
}

/// Where an item stands.
public enum OutboxItemState: Codable, Hashable, Sendable {
  /// Waiting to be sent, with the last answer when it has been tried.
  case pending(lastAnswer: OutboxAnswer?)
  /// Being sent. Found so when the store opens, it is pending again: its key makes the resend
  /// safe.
  case inFlight
  /// Not sent again until the diver edits or discards it.
  case failed(OutboxFailure)
}

/// What the server, or the lack of one, answered a try that left the item pending.
public enum OutboxAnswer: Codable, Hashable, Sendable {
  /// No answer: no route, a timeout.
  case unreachable
  case status(Int)

  /// *Last try: the server answered 500*.
  public var sentence: String {
    switch self {
    case .unreachable: "Last try: the server could not be reached"
    case .status(let status): "Last try: the server answered \(status)"
    }
  }
}

/// Why an item is failed.
public struct OutboxFailure: Codable, Hashable, Sendable {
  public enum Kind: String, Codable, Hashable, Sendable {
    /// The server refused it with a 4xx; `message` is its `detail`.
    case refused
    /// A record it names landed in a form this build could not read, or was deleted, so the
    /// reference can never be resolved.
    case unresolvable
    /// Written for another account before the account was known, about a record of that
    /// account's.
    case wrongAccount
  }

  public var kind: Kind
  public var status: Int?
  /// The sentence the pending screen shows, verbatim.
  public var message: String

  public init(kind: Kind, status: Int? = nil, message: String) {
    self.kind = kind
    self.status = status
    self.message = message
  }
}
