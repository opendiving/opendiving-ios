/// `POST /auth/email/verify`'s body: the sign-in link's token, and the window the session it
/// starts may sit unused for.
public struct EmailVerifyRequest: Codable, Hashable, Sendable {
  public var token: String
  public var idleTimeout: IdleTimeout

  public init(token: String, idleTimeout: IdleTimeout) {
    self.token = token
    self.idleTimeout = idleTimeout
  }
}
