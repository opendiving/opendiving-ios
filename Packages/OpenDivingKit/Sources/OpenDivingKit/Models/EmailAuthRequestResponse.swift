import Foundation

/// `POST /auth/email/request`. Answered alike for every address, invited or not.
public struct EmailAuthRequestResponse: Codable, Hashable, Sendable {
  public let message: String
  /// What `POST /auth/email/verify-code` names alongside the six digits.
  public let requestId: UUID
}
