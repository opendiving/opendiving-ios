/// What redeeming a sign-in code answers. Branch on ``status``, never on whether a token
/// came back: only `authenticated` signed anybody in.
public struct AuthOutcome: Codable, Hashable, Sendable {
  /// `authenticated`, `onboarding_required` or `deletion_pending`.
  public let status: String
  public let accessToken: String?
  public let tokenType: String?
  public let onboardingToken: String?
  public let name: String?
  public let restoreToken: String?
  /// When the account stops being recoverable; null for a row flagged with no clock.
  public let purgeAfter: DiveTimestamp?
  /// The address the code was sent to, on the two outcomes that are not a sign-in.
  public let email: String?
}
