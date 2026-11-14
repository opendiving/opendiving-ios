/// The diver's own invite link, as `GET /user/invite-link` and `POST /user/invite-link` answer
/// it. The token is a bearer credential — whoever follows `/join?via={token}` may create an
/// account, counted as the diver's invitation — so the phone keeps it only as a secret, beside
/// the session's, never in a file.
public struct InviteLinkRead: Codable, Hashable, Sendable {
  public let token: String
  public let createdAt: DiveTimestamp

  public init(token: String, createdAt: DiveTimestamp) {
    self.token = token
    self.createdAt = createdAt
  }
}
