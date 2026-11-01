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

  /// Why a *Sign out* of `origin` left the session as it was; nil when it did not, or when the
  /// user stopped waiting — a session left open on the server is not signed out.
  public func failure(_ origin: ServerOrigin) -> String? {
    switch self {
    case .signedOut, .stopped:
      nil
    case .failed(let reason):
      reason
    case .timedOut:
      "\(origin) did not answer, so you are still signed in. Changing server"
        + (origin.isFlagship ? " does" : " or forgetting this one does") + " not need it to."
    }
  }
}
