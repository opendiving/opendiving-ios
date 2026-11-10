import Observation

/// *Settings*: the server card with the servers screen, a row per section, signing out, and
/// the app.
@MainActor
@Observable
public final class SettingsModel {
  public let session: Session
  public let signIn: SignInFlow
  /// What the last sign-out could not do: one the server did not take, which leaves the
  /// session as it was.
  public private(set) var error: String?

  public init(session: Session, signIn: SignInFlow) {
    self.session = session
    self.signIn = signIn
  }

  public var origin: ServerOrigin? { session.state.origin }

  /// While a sign-out is waited for, nothing else here starts.
  public var isWorking: Bool { signIn.signingOut != nil }

  /// The build the server last reported, updating while ``load()`` asks it again.
  public var card: ServerCardContent? { session.serverCard }

  /// The sections the active server offers, in the web's order.
  public var sections: [SettingsSection] {
    SettingsSection.offered(by: session.server?.config)
  }

  public func load() async {
    await session.loadServerInfo()
  }

  /// Signs out on the server. Anything short of the server ending the session leaves it as it
  /// was, and says why unless the user stopped waiting.
  public func signOut() async {
    guard let origin, !isWorking else { return }
    error = nil
    error = await signIn.signOut(of: origin).failure(origin)
  }
}
