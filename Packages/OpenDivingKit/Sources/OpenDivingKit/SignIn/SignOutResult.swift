/// What waiting for a server to sign out came to.
public enum SignOutResult: Hashable, Sendable {
  /// The server ended the session, or had already.
  case signedOut
  /// The server answered with an error, or could not be reached: the sentence says which.
  case failed(String)
  /// No answer within ``SignInFlow/signOutWait``.
  case timedOut
  /// The user stopped waiting.
  case stopped
}
