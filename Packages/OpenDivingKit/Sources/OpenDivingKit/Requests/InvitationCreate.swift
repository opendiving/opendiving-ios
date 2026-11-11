/// `POST /user/invitations`' body: the address to invite, and nothing else.
public struct InvitationCreate: Codable, Hashable, Sendable {
  public var email: String

  public init(email: String) {
    self.email = email
  }
}
