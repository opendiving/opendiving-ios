import Foundation

/// Whose stores the session names, and what may be done with them.
///
/// Once the account has loaded in this process they are the loaded user's — `Session.user`,
/// never the last-account pointer, whose write can fail while the load returns — and nothing
/// holds them back. Signed in before then they are the pointer's account's, the phone's best
/// knowledge: read and written to, every write marked as made before the account was known,
/// nothing sent and no cache written, since another account's answers could land in them.
/// Signed out they are the pointer's account's, unmarked. With no pointer, there are none.
struct AccountStores: Sendable {
  let store: ServerStateStore
  let origin: ServerOrigin
  let account: UUID
  /// Signed in, account not yet loaded: what is written now is marked.
  let marked: Bool
  /// Signed in with the account loaded: the flush runs and the caches are written.
  let loaded: Bool

  @MainActor
  static func current(_ session: Session) -> AccountStores? {
    guard let origin = session.state.origin else { return nil }
    if case .signedIn = session.state, session.accountLoaded, let user = session.user {
      return AccountStores(
        store: session.store, origin: origin, account: user.uuid, marked: false, loaded: true)
    }
    guard let last = session.store.lastAccount(for: origin) else { return nil }
    let signedIn = if case .signedIn = session.state { true } else { false }
    return AccountStores(
      store: session.store, origin: origin, account: last, marked: signedIn, loaded: false)
  }

  var directory: URL { store.directory(for: origin, account: account) }
  var outbox: OutboxStore { OutboxStore(store: store, origin: origin, account: account) }
  var cache: AccountCache { AccountCache(store: store, origin: origin, account: account) }
  /// The cache, when it may be written.
  var writableCache: AccountCache? { loaded ? cache : nil }

  func sameAccount(_ other: AccountStores?) -> Bool {
    other?.origin == origin && other?.account == account && other?.loaded == loaded
  }
}

/// Whether an answer fetched while the session stood at `before` may be written to the cache
/// of the account the session names now: only once the account has loaded, and only when the
/// fetch either began before any account was known — the token was the loaded account's — or
/// under that same account.
@MainActor
func cacheForAnswer(fetchedUnder before: AccountStores?, session: Session) -> AccountCache? {
  guard let now = AccountStores.current(session), now.loaded else { return nil }
  if let before, before.loaded, before.account != now.account { return nil }
  return now.cache
}
