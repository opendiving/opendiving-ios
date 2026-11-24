/// `POST /auth/complete`'s body: the onboarding token a sign-in with no account answered, which
/// names the address and is spent by the call, and what the new account starts with.
public struct ProfileCompletionRequest: Codable, Hashable, Sendable {
  public var onboardingToken: String
  public var name: String
  public var username: String

  public init(onboardingToken: String, name: String, username: String) {
    self.onboardingToken = onboardingToken
    self.name = name
    self.username = username
  }
}
