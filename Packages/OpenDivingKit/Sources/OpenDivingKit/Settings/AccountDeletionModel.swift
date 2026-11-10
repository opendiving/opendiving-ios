import Foundation
import Observation

/// *Delete my account*: enabled once the username is typed back, as the web compares it —
/// trimmed and without case, since this is friction rather than a password — and never while
/// the archive offered first is still on its way or in the share sheet. A deletion that lands
/// ends the session and leaves the sign-in flow on its goodbye.
@MainActor
@Observable
public final class AccountDeletionModel {
  /// What the screen says before anything is typed, in the web's words.
  public static let warning =
    "This erases your whole logbook: every dive and its profile, your dive drafts, your dive"
    + " sites, trips, gear and service history, your courses, your certifications and the scans"
    + " of your cards, your contacts and people, your tags, and the dive-computer files you"
    + " imported. Take a copy first if you might want any of it — afterwards there is nowhere"
    + " to take it from."
  /// Above the delete, on the Account screen.
  public static let summary =
    "Deleting locks you out straight away, on this phone and every other device. Your dives,"
    + " dive drafts, dive sites, trips, courses, certifications, gear, contacts, people, tags and"
    + " profile are then erased for good once this server's grace period runs out. We'll email"
    + " you the exact date; nothing is erased before it, and signing in again before then brings"
    + " the account back."

  public private(set) var typed = ""
  public private(set) var isDeleting = false
  /// Why the last delete did nothing.
  public private(set) var failure: String?

  /// The archive *Download my data first* fetches.
  public let exports: DataExportModel
  @ObservationIgnored private let signIn: SignInFlow

  public init(signIn: SignInFlow, exports: DataExportModel) {
    self.signIn = signIn
    self.exports = exports
  }

  public convenience init(signIn: SignInFlow) {
    self.init(signIn: signIn, exports: DataExportModel(session: signIn.session))
  }

  /// What has to be typed back.
  public var username: String? { signIn.session.user?.username }

  public func setTyped(_ text: String) {
    typed = text
  }

  public var isConfirmed: Bool {
    guard let username else { return false }
    return typed.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      == username.lowercased()
  }

  public var canDelete: Bool { isConfirmed && !isDeleting && !exports.isBusy }

  /// Starts the archive download.
  public func downloadFirst() {
    guard !isDeleting else { return }
    exports.start(.archive)
  }

  /// Deletes the account. With no route nothing is sent; a refusal is the API's sentence.
  public func delete() async {
    guard canDelete else { return }
    failure = nil
    isDeleting = true
    do {
      try await signIn.deleteAccount()
      // Left deleting: the screen goes with the session, and an armed button in the frames
      // before it does would offer a second delete of an account already gone.
    } catch {
      isDeleting = false
      failure = APIError(error).message
    }
  }
}
