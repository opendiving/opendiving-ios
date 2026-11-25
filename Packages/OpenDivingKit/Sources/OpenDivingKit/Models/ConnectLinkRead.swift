/// The diver's own connect link, as `GET /user/connect-link` and `POST /user/connect-link`
/// answer it. The token is a bearer credential — whoever opens `/connect/{token}` sees the
/// diver's name and picture and can connect to them, and on an invite-only instance create an
/// account counted as the diver's invitation — so the phone keeps it only as a secret, beside the
/// session's, never in a file.
public struct ConnectLinkRead: Codable, Hashable, Sendable {
  public let token: String
  public let createdAt: DiveTimestamp

  public init(token: String, createdAt: DiveTimestamp) {
    self.token = token
    self.createdAt = createdAt
  }
}
