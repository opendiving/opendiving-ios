import Foundation
import Observation

/// *Account*'s profile picture, name and username, saved together by one *Save* that sends only
/// what changed, within the web's bounds. A field the diver has not touched shows the account as
/// the session holds it, so a read that lands while the screen shows reaches it.
///
/// ``save()`` sends the fields first, and only when one changed; the picture goes after them, so
/// a picture the server refuses leaves the fields saved and says so. A refusal stands only beside
/// what it refused, where the web's form keeps its own until the next submit: changing what it
/// refused takes it away, and changing anything else leaves it showing.
@MainActor
@Observable
public final class AccountFormModel {
  public static let nameBounds = 2...30
  public static let usernameBounds = 2...20
  /// What the web says once a save lands.
  public static let savedMessage = "Your profile has been updated."

  public let write: AccountWrite
  public let picture: PictureFieldModel
  @ObservationIgnored private let session: Session

  /// What the diver typed, until it is saved; nil shows the account's own.
  private var nameEdit: String?
  private var usernameEdit: String?
  /// Whether the last save landed, until the next edit: a picture chosen since is one.
  public var saved: Bool { lastSaveLanded && picture.edit == nil }
  private var lastSaveLanded = false
  /// Why the last save stored nothing, or stored the fields and not the picture. A refusal of the
  /// fields goes once a field that save sent is edited, one of the picture once the picture
  /// changes, and either at the next save — which may send no fields, so an earlier refusal of
  /// them is never left showing.
  public var failure: String? {
    switch refusal {
    case .fields(let message, _, _): message
    case .picture(let message, let revision): picture.revision == revision ? message : nil
    case nil: nil
    }
  }

  /// What the last save's refusal was of, which says what takes it away.
  private enum Refusal {
    /// The fields, with which of them that save sent.
    case fields(String, name: Bool, username: Bool)
    /// The picture, at the ``PictureFieldModel/revision`` it was refused at: any change of the
    /// picture moves it on.
    case picture(String, revision: Int)
  }
  private var refusal: Refusal?

  public init(session: Session) {
    self.session = session
    write = AccountWrite(session: session)
    picture = PictureFieldModel(kind: .avatar, session: session)
  }

  /// Whether there is an account to edit yet.
  public var isLoaded: Bool { session.user != nil }

  public var name: String { nameEdit ?? storedName }
  public var username: String { usernameEdit ?? storedUsername }

  public func setName(_ text: String) {
    nameEdit = text
    lastSaveLanded = false
    if case .fields(_, name: true, _) = refusal { refusal = nil }
  }

  public func setUsername(_ text: String) {
    usernameEdit = text
    lastSaveLanded = false
    if case .fields(_, _, username: true) = refusal { refusal = nil }
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

  public var hasChanges: Bool { fieldsUpdate != nil || picture.edit != nil }

  public var isSaving: Bool { write.isSaving || picture.isSending }

  public var canSave: Bool {
    isLoaded && hasChanges && nameProblem == nil && usernameProblem == nil && !isSaving
  }

  /// Sends what changed. A refusal of the fields — a username another account holds, the rename
  /// limit — is ``failure``, what was typed stays, and the picture is not sent. A refusal of the
  /// picture is ``failure`` too, saying whether the fields saved, and the picture stays picked.
  public func save() async {
    guard canSave else { return }
    lastSaveLanded = false
    refusal = nil
    var fieldsSaved = false
    if let update = fieldsUpdate {
      guard await write.save(update) else {
        refusal = write.failure.map {
          .fields($0, name: update.name != nil, username: update.username != nil)
        }
        return
      }
      nameEdit = nil
      usernameEdit = nil
      fieldsSaved = true
    }
    if picture.edit != nil, let refused = await picture.send() {
      refusal = .picture(
        picture.kind.notSaved(refused, afterFields: fieldsSaved), revision: picture.revision)
      return
    }
    lastSaveLanded = true
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
