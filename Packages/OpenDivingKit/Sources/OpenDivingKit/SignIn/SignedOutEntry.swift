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

  /// What the entry is, behind its info button. Only a server that can be forgotten mentions it.
  public func info(on origin: ServerOrigin) -> String {
    let kept = origin.isFlagship ? "" : ", until you forget the server"
    return switch self {
    case .logDive:
      "Log a dive without signing in. It's saved for the account last signed in here, and syncs"
        + " when that account signs in again. Signing in to a different account won't send it."
    case .waitingToSync:
      "What the account last signed in here saved on this phone and hasn't reached the server."
        + " It stays here after you sign out\(kept), and syncs when that account signs in again."
        + " Signing in to a different account won't send it."
    case .checkInSheet:
      "Your certification cards, ready to show at a dive centre's counter, even with no signal."
        + " The sheet stays on this phone after you sign out\(kept)."
    }
  }
}
