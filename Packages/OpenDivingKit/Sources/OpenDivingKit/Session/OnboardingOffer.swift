/// A sign-in's answer for an address with no account: the onboarding token that creates one,
/// held in memory for as long as the sign-up screen, and written nowhere — not to a file, not to
/// the Keychain, not to a log. It prints as redacted wherever it is described.
public struct OnboardingOffer: Hashable, Sendable {
  let token: String
}

extension OnboardingOffer: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable
{
  public var description: String { "OnboardingOffer(redacted)" }
  public var debugDescription: String { description }
  public var customMirror: Mirror { Mirror(self, children: [], displayStyle: .struct) }
}
