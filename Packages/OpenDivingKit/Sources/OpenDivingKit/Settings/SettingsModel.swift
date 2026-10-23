import Observation

/// The *Settings* tab: the server and the build it runs, the account, and the three ways out
/// of it — signing out, changing server and forgetting the server.
@MainActor
@Observable
public final class SettingsModel {
  public let session: Session
  private let signIn: SignInFlow
  public private(set) var isWorking = false
  /// Why the last sign-out failed. The session is as it was.
  public private(set) var error: String?

  public init(session: Session, signIn: SignInFlow) {
    self.session = session
    self.signIn = signIn
  }

  public var origin: ServerOrigin? { session.state.origin }

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

  /// Signs out on the server. On failure the session stays and the error is shown: a session
  /// left open on the server is not signed out.
  public func signOut() async {
    _ = await performSignOut()
  }

  /// Signs out, then the server screen. The server's cached sheet stays on the phone.
  public func changeServer() async {
    guard await performSignOut() else { return }
    signIn.useDifferentServer()
  }

  /// Signs out if it can, then removes everything kept for the server either way.
  public func forget() async {
    guard let origin, !isWorking else { return }
    isWorking = true
    defer { isWorking = false }
    error = nil
    error = await signIn.forget(origin)
  }

  private func performSignOut() async -> Bool {
    guard !isWorking else { return false }
    isWorking = true
    defer { isWorking = false }
    error = nil
    do {
      try await session.signOut()
      return true
    } catch {
      let error = APIError(error)
      // The server refused the session, which ended it as surely as a sign-out.
      if error == .signedOut { return true }
      self.error = error.message
      return false
    }
  }
}
