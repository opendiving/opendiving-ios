/// What the sign-in screen offers, besides signing in, while the phone is pointed at a server
/// and signed out of it: what the phone keeps for that server, another server, and forgetting
/// this one.
public enum SignedOutEntry: Hashable, Sendable, CaseIterable, Identifiable {
  /// The cached check-in sheet, which renders with no session.
  case checkInSheet
  /// The pending screen of the account last loaded here — its drafts, its writes waiting to
  /// sync and its files waiting to be read — where a dive can still be logged. Offered only
  /// while the server has such an account.
  case waitingToSync
  /// The servers screen: the saved servers and a field for another. What the phone keeps for
  /// the current server stays on it.
  case differentServer
  /// Everything kept for the server, removed — the one way to clear what the phone keeps for a
  /// server that can no longer be signed in to.
  case forgetServer

  public var id: Self { self }
}
