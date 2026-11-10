/// `DELETE /user/sessions`' answer. The count is the payload: the confirmation comes before
/// the request, so how many devices were signed out can come only from here.
public struct SessionsRevoked: Codable, Hashable, Sendable {
  public let message: String
  public let revoked: Int

  public init(message: String, revoked: Int) {
    self.message = message
    self.revoked = revoked
  }
}
