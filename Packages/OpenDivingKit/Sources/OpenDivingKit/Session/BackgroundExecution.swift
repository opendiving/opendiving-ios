/// Keeps the app running while work that must not be cut off finishes: a token rotating, a
/// queue flushing. `/auth/refresh` spends the presented token before it answers, so a response
/// lost to suspension leaves a spent token behind, which the API takes again only inside its
/// reuse grace, a minute by default; a phone suspended past that is signed out at its next
/// refresh. The app target conforms over
/// `UIApplication.beginBackgroundTask(withName:expirationHandler:)`.
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
