import Observation

/// The *Settings* tab: the server card with the servers screen and signing out, and the
/// account.
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

  /// The version reads `Unknown` until the server has answered ``load()``.
  public var card: ServerCardContent? { session.serverCard }

  public var unitsLabel: String {
    switch session.units {
    case .metric: "Metric"
    case .imperial: "Imperial"
    }
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
