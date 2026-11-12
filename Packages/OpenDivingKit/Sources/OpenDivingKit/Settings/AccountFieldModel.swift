import Foundation
import Observation

/// One of *Account*'s two fields, the name or the username, on a screen of its own and saved by
/// that screen's *Save*, within the web's bounds. Until the diver types it shows the account as
/// the session holds it, with what ``AccountWrite`` has taken laid over it, so a read that lands
/// while the screen shows reaches it.
@MainActor
@Observable
public final class AccountFieldModel {
  public enum Field: Hashable, Sendable {
    case name, username

    public var label: String {
      switch self {
      case .name: "Name"
      case .username: "Username"
      }
    }

    public var bounds: ClosedRange<Int> {
      switch self {
      case .name: 2...30
      case .username: 2...20
      }
    }
  }

  public let field: Field
  @ObservationIgnored private let write: AccountWrite
  @ObservationIgnored private let session: Session

  /// What the diver typed, until it is saved; nil shows the account's own.
  private var edit: String?
  /// Why the last save stored nothing, until the next edit or save.
  public private(set) var failure: String?

  /// `write` is the screen's that shows the account, so a save whose read fails still shows
  /// there.
  public init(field: Field, write: AccountWrite, session: Session) {
    self.field = field
    self.write = write
    self.session = session
  }

  /// The field as the account holds it, with what `write` has taken laid over it.
  public static func shown(_ field: Field, write: AccountWrite, session: Session) -> String {
    switch field {
    case .name: write.shown?.name ?? session.user?.name ?? ""
    case .username: write.shown?.username ?? session.user?.username ?? ""
    }
  }

  public var text: String { edit ?? stored }

  public func setText(_ text: String) {
    edit = text
    failure = nil
  }

  /// Why the text, as it would be sent, would be refused; nil when it would not.
  public var problem: String? {
    let text = trimmed
    if text.count < field.bounds.lowerBound {
      return "\(field.label) must be at least \(field.bounds.lowerBound) characters"
    }
    if text.count > field.bounds.upperBound {
      return "\(field.label) cannot exceed \(field.bounds.upperBound) characters"
    }
    guard field == .username else { return nil }
    let allowed = text.unicodeScalars.allSatisfy {
      ("a"..."z").contains($0) || ("0"..."9").contains($0)
    }
    return allowed ? nil : "Username can only contain lowercase letters and numbers"
  }

  /// The change, trimmed as it is sent; nil when there is none.
  public var update: UserUpdate? {
    let text = trimmed
    guard text != stored else { return nil }
    switch field {
    case .name: return UserUpdate(name: text)
    case .username: return UserUpdate(username: text)
    }
  }

  public var isSaving: Bool { write.isSaving }

  public var canSave: Bool {
    session.user != nil && update != nil && problem == nil && !isSaving
  }

  /// Sends the change. False when nothing was saved — a username another account holds, the
  /// rename limit, no connection — with ``failure`` saying why and what was typed kept.
  public func save() async -> Bool {
    guard canSave, let update else { return false }
    failure = nil
    guard await write.save(update) else {
      failure = write.failure
      return false
    }
    edit = nil
    return true
  }

  private var stored: String { Self.shown(field, write: write, session: session) }

  private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
}
