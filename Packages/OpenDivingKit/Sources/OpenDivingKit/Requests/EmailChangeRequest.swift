/// `POST /user/email-change/request`'s body: the address a confirmation link is sent to. The
/// account's email changes only once that link is confirmed, on the web.
public struct EmailChangeRequest: Codable, Hashable, Sendable {
  public var newEmail: String

  public init(newEmail: String) {
    self.newEmail = newEmail
  }
}
