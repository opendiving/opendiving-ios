/// The diver's own invite link, as `GET /user/invite-link` and `POST /user/invite-link` answer
/// it. The token is a bearer credential — whoever follows `/join?via={token}` may create an
/// account, counted as the diver's invitation — and the server keeps it readable, so it is
/// read again on every visit rather than kept on the phone.
public struct InviteLinkRead: Codable, Hashable, Sendable {
  public let token: String
  public let createdAt: DiveTimestamp

  public init(token: String, createdAt: DiveTimestamp) {
    self.token = token
    self.createdAt = createdAt
  }
}
