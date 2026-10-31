import Observation

/// The *Settings* tab: the server and the build it runs, the account, and the ways out of it —
/// the servers screen, signing out and forgetting the server.
@MainActor
@Observable
public final class SettingsModel {
  public let session: Session
  public let signIn: SignInFlow
  /// What the last action could not do: a sign-out the server did not take, which leaves the
  /// session as it was, or a *Forget* that could not remove everything kept for the server.
  public private(set) var error: String?

  public init(session: Session, signIn: SignInFlow) {
    self.session = session
    self.signIn = signIn
  }

  public var origin: ServerOrigin? { session.state.origin }

  /// While a sign-out is waited for, nothing else here starts.
  public var isWorking: Bool { signIn.signingOut != nil }

  /// The version the server reported, or `Unknown` until it has answered — after a cold start
  /// nothing has asked it yet.
  public var serverVersion: String { session.server?.health?.version ?? "Unknown" }
  public var serverCommit: String { session.server?.health?.commit ?? "Unknown" }

  public var unitsLabel: String {
    switch session.units {
    case .metric: "Metric"
    case .imperial: "Imperial"
    }
  }

  /// Asks the server what it runs when nothing has since the app started; a failure leaves the
  /// version unknown.
  public func load() async {
    guard session.server == nil, let origin else { return }
    _ = try? await session.validate(origin)
  }

  /// Signs out on the server. Anything short of the server ending the session leaves it as it
  /// was, and says why unless the user stopped waiting: a session left open on the server is
  /// not signed out.
  public func signOut() async {
    guard let origin, !isWorking else { return }
    error = nil
    switch await signIn.signOut(of: origin) {
    case .signedOut, .stopped:
      break
    case .failed(let reason):
      error = reason
    case .timedOut:
      error =
        "\(origin) did not answer, so you are still signed in. Changing server or forgetting"
        + " this one does not need it to."
    }
  }

  /// Signs out if it can, then removes everything kept for the server either way.
  public func forget() async {
    guard let origin, !isWorking else { return }
    error = nil
    error = await signIn.forget(origin)
    // Still signed in, Settings is still on screen and shows the failure itself; a sign-out
    // that worked has left it for the sign-in screen, which shows the notice.
    if error != nil, session.state == .signedIn(origin) { signIn.dismissNotice() }
  }
}
