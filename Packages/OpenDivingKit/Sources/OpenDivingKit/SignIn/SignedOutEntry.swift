/// What the sign-in screen offers, besides signing in and changing server, while the phone is
/// pointed at a server and signed out of it: what the phone keeps for that server.
public enum SignedOutEntry: Hashable, Sendable, CaseIterable, Identifiable {
  /// The dive form, over the stores of the account last loaded here. Offered only while the
  /// server has such an account.
  case logDive
  /// The pending screen of that account — its drafts, its writes waiting to sync and its files
  /// waiting to be read. Offered only while the server has such an account, and drawn only
  /// while ``PendingText/signedOutWaiting(drafts:items:unreadable:files:)`` has a line for it.
  case waitingToSync
  /// The cached check-in sheet, which renders with no session.
  case checkInSheet

  public var id: Self { self }
}
