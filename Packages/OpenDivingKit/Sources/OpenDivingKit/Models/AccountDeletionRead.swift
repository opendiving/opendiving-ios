/// `DELETE /user`'s answer. The account is dark from the moment it is sent, so this is the
/// only place the phone learns the day it is erased on.
public struct AccountDeletionRead: Codable, Hashable, Sendable {
  public let message: String
  /// When the account stops being recoverable by signing in.
  public let purgeAfter: DiveTimestamp
}
