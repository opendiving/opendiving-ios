import Observation

/// Loads the account and the people table whenever the session becomes signed in: on a cold
/// start with a token in the Keychain, which refreshes first, and after a sign-in. A refused
/// session lands on the sign-in screen through ``Session/state``; any other failure keeps the
/// session and is reported here.
@MainActor
@Observable
public final class AccountLoader {
  public let session: Session
  /// The sentence to show when the last load failed for any reason but a refused session.
  public private(set) var failure: String?
  @ObservationIgnored private var launched = false

  public init(session: Session) {
    self.session = session
  }

  /// A cold start: a session that came up signed in refreshes, then loads the account. Runs
  /// once per loader.
  public func launch() async {
    guard !launched else { return }
    launched = true
    guard case .signedIn = session.state else { return }
    await run { try await self.session.resume() }
  }

  /// Loads the account when the session has just become signed in.
  public func sessionChanged(from old: Session.State, to new: Session.State) async {
    guard case .signedIn = new, old != new else {
      failure = nil
      return
    }
    await run { try await self.session.loadAccount() }
  }

  /// Another try after a failure; the client refreshes first when it holds no access token.
  public func retry() async {
    failure = nil
    guard case .signedIn = session.state else { return }
    await run { try await self.session.loadAccount() }
  }

  public func dismissFailure() {
    failure = nil
  }

  private func run(_ load: () async throws -> Void) async {
    do {
      try await load()
      failure = nil
    } catch {
      let error = APIError(error)
      failure = error == .signedOut ? nil : error.message
    }
  }
}
