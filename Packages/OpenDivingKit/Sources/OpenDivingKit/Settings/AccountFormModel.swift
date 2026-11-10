import Foundation
import Observation

/// *Account*'s name and username, saved together by one *Save* that sends only what changed,
/// within the web's bounds. A field the diver has not touched shows the account as the session
/// holds it, so a read that lands while the screen shows reaches it.
///
/// ``save()`` sends the fields first, and only when one changed; whatever else rides the form's
/// save goes after them, so that ``hasChanges`` and ``save()`` are where it is added.
@MainActor
@Observable
public final class AccountFormModel {
  public static let nameBounds = 2...30
  public static let usernameBounds = 2...20
  /// What the web says once a save lands.
  public static let savedMessage = "Your profile has been updated."

  public let write: AccountWrite
  @ObservationIgnored private let session: Session

  /// What the diver typed, until it is saved; nil shows the account's own.
  private var nameEdit: String?
  private var usernameEdit: String?
  /// Whether the last save landed, until the next edit.
  public private(set) var saved = false

  public init(session: Session) {
    self.session = session
    write = AccountWrite(session: session)
  }

  /// Whether there is an account to edit yet.
  public var isLoaded: Bool { session.user != nil }

  public var name: String { nameEdit ?? storedName }
  public var username: String { usernameEdit ?? storedUsername }

  public func setName(_ text: String) {
    nameEdit = text
    saved = false
  }

  public func setUsername(_ text: String) {
    usernameEdit = text
    saved = false
  }

  /// Why the name, as it would be sent, would be refused; nil when it would not.
  public var nameProblem: String? {
    Self.lengthProblem("Name", trimmed(name), Self.nameBounds)
  }

  /// Why the username, as it would be sent, would be refused; nil when it would not.
  public var usernameProblem: String? {
    let username = trimmed(username)
    if let problem = Self.lengthProblem("Username", username, Self.usernameBounds) {
      return problem
    }
    let allowed = username.unicodeScalars.allSatisfy {
      ("a"..."z").contains($0) || ("0"..."9").contains($0)
    }
    return allowed ? nil : "Username can only contain lowercase letters and numbers"
  }

  /// The fields that changed, trimmed as they are sent; nil when neither did.
  public var fieldsUpdate: UserUpdate? {
    let name = trimmed(name)
    let username = trimmed(username)
    let update = UserUpdate(
      name: name == storedName ? nil : name,
      username: username == storedUsername ? nil : username)
    return update == UserUpdate() ? nil : update
  }

  public var hasChanges: Bool { fieldsUpdate != nil }

  public var canSave: Bool {
    isLoaded && hasChanges && nameProblem == nil && usernameProblem == nil && !write.isSaving
  }

  /// Sends what changed. A refusal — a username another account holds, the rename limit — is
  /// ``AccountWrite/failure``, and what was typed stays.
  public func save() async {
    guard canSave else { return }
    saved = false
    if let update = fieldsUpdate {
      guard await write.save(update) else { return }
      nameEdit = nil
      usernameEdit = nil
    }
    saved = true
  }

  private var storedName: String { write.shown?.name ?? session.user?.name ?? "" }
  private var storedUsername: String { write.shown?.username ?? session.user?.username ?? "" }

  private func trimmed(_ text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func lengthProblem(_ label: String, _ text: String, _ bounds: ClosedRange<Int>)
    -> String?
  {
    if text.count < bounds.lowerBound {
      return "\(label) must be at least \(bounds.lowerBound) characters"
    }
    if text.count > bounds.upperBound {
      return "\(label) cannot exceed \(bounds.upperBound) characters"
    }
    return nil
  }
}
