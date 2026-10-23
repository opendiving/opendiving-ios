/// Keeps the app running while a token rotates. `/auth/refresh` spends the presented token
/// before it answers, so a response lost to suspension leaves a spent token behind, and the
/// next refresh signs the phone out and may revoke the session as a replay. The app target
/// conforms over `UIApplication.beginBackgroundTask(withName:expirationHandler:)`.
public protocol BackgroundExecution: Sendable {
  func begin(name: String) async -> BackgroundExecutionToken
  func end(_ token: BackgroundExecutionToken) async
}

/// One assertion ``BackgroundExecution`` handed out.
public struct BackgroundExecutionToken: Hashable, Sendable {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }
}
