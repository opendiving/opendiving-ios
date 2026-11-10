import Observation

/// A rename made in the row itself, wherever a list offers one — a tag, a passkey: one row at a
/// time turns into a field, saved with the trimmed name and stopped without a request when the
/// name is unchanged. An empty name, or one longer than `maxLength`, cannot be saved. A
/// refusal keeps the row open, the typed name in it, with the API's sentence.
@MainActor
@Observable
public final class InlineRename<ID: Hashable & Sendable> {
  /// The row being renamed.
  public private(set) var editing: ID?
  /// What the field holds.
  public var draft = ""
  public private(set) var isSaving = false
  /// Why the last save did not rename, until the row is opened or stopped.
  public private(set) var failure: String?
  /// The longest name the server stores, in code points as the API counts them; nil for no
  /// bound here.
  public let maxLength: Int?

  @ObservationIgnored private var original = ""

  public init(maxLength: Int? = nil) {
    self.maxLength = maxLength
  }

  public func begin(_ id: ID, name: String) {
    guard !isSaving else { return }
    editing = id
    draft = name
    original = name
    failure = nil
  }

  public func stop() {
    guard !isSaving else { return }
    editing = nil
    draft = ""
    failure = nil
  }

  /// The name as it would be sent.
  public var name: String { draft.trimmedOfWhitespace }

  public var canSave: Bool {
    guard editing != nil, !isSaving, !name.isEmpty else { return false }
    return maxLength.map { name.unicodeScalars.count <= $0 } ?? true
  }

  /// Sends the name through `send` and closes the row. True only when a rename was sent and
  /// taken; an unchanged name closes the row and sends nothing.
  public func save(_ send: (ID, String) async throws -> Void) async -> Bool {
    guard canSave, let id = editing else { return false }
    let name = name
    guard name != original else {
      stop()
      return false
    }
    failure = nil
    isSaving = true
    do {
      try await send(id, name)
    } catch {
      isSaving = false
      failure = APIError(error).message
      return false
    }
    isSaving = false
    stop()
    return true
  }
}
