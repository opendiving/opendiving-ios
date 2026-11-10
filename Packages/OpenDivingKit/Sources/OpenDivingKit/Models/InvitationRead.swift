import Foundation

/// One invitation the diver sent, as `GET /user/invitations` lists it. Pending is both stamps
/// nil; the API never revokes an accepted one, so the two never meet.
public struct InvitationRead: Codable, Hashable, Sendable, Identifiable {
  public let uuid: UUID
  /// The address invited. Nil on a row somebody made by following the diver's invite link:
  /// the diver never typed that address and is never given it.
  public let email: String?
  public let createdAt: DiveTimestamp
  public let acceptedAt: DiveTimestamp?
  public let revokedAt: DiveTimestamp?
  /// Made by somebody signing up through the diver's invite link, accepted from birth.
  public let fromInviteLink: Bool
  /// On a link row, the current name of the account it admitted; nil once none matches.
  public let memberName: String?

  public var id: UUID { uuid }

  public init(
    uuid: UUID, email: String?, createdAt: DiveTimestamp, acceptedAt: DiveTimestamp?,
    revokedAt: DiveTimestamp?, fromInviteLink: Bool, memberName: String?
  ) {
    self.uuid = uuid
    self.email = email
    self.createdAt = createdAt
    self.acceptedAt = acceptedAt
    self.revokedAt = revokedAt
    self.fromInviteLink = fromInviteLink
    self.memberName = memberName
  }

  /// Neither accepted nor revoked: the address can still create an account, and the
  /// invitation can still be revoked.
  public var isPending: Bool { acceptedAt == nil && revokedAt == nil }
}
