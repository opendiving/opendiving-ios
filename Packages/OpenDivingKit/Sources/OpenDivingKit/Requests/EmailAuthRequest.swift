/// `POST /auth/email/request`'s body: the address to mail the link and the code to, and the
/// connect link's token a sign-in started from, which admits a newcomer to an invite-only server
/// and starts the new account with the link's owner in its people.
public struct EmailAuthRequest: Codable, Hashable, Sendable {
  public var email: String
  public var via: String?

  public init(email: String, via: String? = nil) {
    self.email = email
    self.via = via
  }
}
