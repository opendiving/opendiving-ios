import Foundation
import Observation

/// A saved server's page, opened from the servers screen: its card, the account signed in
/// there, when it was last used, and signing out of it or forgetting it.
@MainActor
@Observable
public final class SavedServerModel {
  public let origin: ServerOrigin
  public let signIn: SignInFlow
  /// What the last action could not do: a sign-out the server did not take, which leaves the
  /// session as it was, or a *Forget* that could not remove everything kept for the server.
  public private(set) var error: String?
  /// What the server answered when this page asked it; the active server's is the session's.
  private var info: ServerInfo?
  @ObservationIgnored private let timeZone: TimeZone

  public init(origin: ServerOrigin, signIn: SignInFlow, timeZone: TimeZone = .current) {
    self.origin = origin
    self.signIn = signIn
    self.timeZone = timeZone
  }

  private var session: Session { signIn.session }

  public var isActive: Bool { session.state.origin == origin }

  public var card: ServerCardContent {
    session.card(for: origin, answered: info)
  }

  public var isSignedIn: Bool { session.isSignedIn(to: origin) }

  /// Every server but the flagship, which stays on the list.
  public var canForget: Bool { !origin.isFlagship }

  /// The address signed in there, or a placeholder before its account has loaded; nil when
  /// signed out.
  public var signedInAs: String? {
    guard isSignedIn else { return nil }
    return session.account(on: origin)?.email ?? "Account not loaded yet"
  }

  /// *Now* for the active server, else when it was left, in the phone's zone.
  public var lastUsed: String {
    if isActive { return "Now" }
    return session.store.lastUsed(origin).map { DateText.dateTime($0, in: timeZone) }
      ?? "Unknown"
  }

  /// While a sign-out is waited for, nothing else here starts.
  public var isWorking: Bool { signIn.signingOut != nil }

  /// Asks the server again what it runs; a failure leaves the build it last reported.
  public func load() async {
    if isActive {
      await session.loadServerInfo()
    } else if let answered = try? await session.validate(origin) {
      info = answered
    }
  }

  /// Signs out on the server, as Settings does.
  public func signOut() async {
    guard isSignedIn, !isWorking else { return }
    error = nil
    error = await signIn.signOut(of: origin).failure(origin)
  }

  /// Signs out if it can, then removes everything kept for the server either way. Answers
  /// whether it was all removed, which leaves this page with nothing to show.
  public func forget() async -> Bool {
    guard canForget, !isWorking else { return false }
    error = nil
    let before = session.state
    error = await signIn.forget(origin)
    // While the session is as it was, this page is still on screen and shows the failure
    // itself; a sign-out of the active server has left it for the sign-in screen, which shows
    // the notice.
    if error != nil, session.state == before { signIn.dismissNotice() }
    return error == nil
  }
}
