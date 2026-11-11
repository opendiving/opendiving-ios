import Foundation
import Observation

/// One paginated list as a screen shows it: the first page on appear, the next on reaching
/// the end while the server says there is more, and pull-to-refresh, which reloads the
/// account and the people table before page 1 — every list a screen draws names people.
///
/// Given a cache key, the pages it loads are kept for the account, and on appear the kept
/// pages show at once under ``lastUpdated`` while page 1 is fetched behind them; a fetch that
/// fails leaves them standing. Nothing waits for a request to fail before showing what the
/// phone has, since a request waits a minute for a route. A page is written only once the
/// account has loaded in this process, so another account's answer never lands in the
/// previous one's cache.
///
/// A list that has loaded fetches every page it shows again, behind the items shown, when the
/// account's records change under it — an import applied, a queued write landed — rather than
/// waiting for a pull, and rather than dropping back to page 1 under a diver scrolled past it.
///
/// A list that names its rows' records leaves out a record whose delete is queued, offline too,
/// and shows it again if the delete is discarded or refused; and, at once, one the server no
/// longer has.
///
/// A list made `routed` asks for nothing while the phone believes it has no route: it fails at
/// once with ``APIError/noRoute``, quietly behind kept pages, and the page that owns it reads
/// again when one appears.
///
/// A load whose task is cancelled has no outcome: nothing it shows says it failed, and a list
/// with nothing fetched is idle again, so the next ``load()`` asks once more.
@MainActor
@Observable
public final class PagedList<Item: Codable & Sendable> {
  public typealias Fetch =
    @Sendable (_ client: APIClient, _ page: Int, _ itemsPerPage: Int) async throws ->
    PaginatedListResponse<Item>

  public enum Phase: Equatable, Sendable {
    case idle
    case loading
    case loaded
    /// The first page failed; there is nothing to show but the error.
    case failed(APIError)
  }

  /// The rows shown: what was fetched, less what is being deleted.
  public private(set) var items: [Item] = []
  public private(set) var phase: Phase = .idle
  public private(set) var hasMore = false
  public private(set) var isLoadingMore = false
  /// A later page, or a refresh, failed while earlier items stay on screen.
  public private(set) var pageError: APIError? = nil
  /// When the items shown were fetched, while they are the cache's rather than this visit's.
  public private(set) var lastUpdated: Date? = nil

  @ObservationIgnored private let session: Session
  @ObservationIgnored private let itemsPerPage: Int
  @ObservationIgnored private let fetch: Fetch
  @ObservationIgnored private let cacheKey: PageCacheKey<Item>?
  @ObservationIgnored private let routed: Bool
  @ObservationIgnored private var fetched: [Item] = []
  @ObservationIgnored private var nextPage = 1
  @ObservationIgnored private var generation = 0
  /// A refresh of a list already on screen leaves its items and its phase alone while its pages
  /// are on their way; a later page asked for in that window would be appended to the new ones.
  @ObservationIgnored private var isReloadingPages = false
  /// The reload a change to the account's records started.
  @ObservationIgnored var reloading: Task<Void, Never>?
  @ObservationIgnored private var watchesAccount = false

  public init(
    session: Session, itemsPerPage: Int = APIClient.listPageSize,
    cache cacheKey: PageCacheKey<Item>? = nil, routed: Bool = false, fetch: @escaping Fetch
  ) {
    self.session = session
    self.itemsPerPage = itemsPerPage
    self.cacheKey = cacheKey
    self.routed = routed
    self.fetch = fetch
  }

  /// The first page, unless it is loaded or loading already — after the kept pages, shown at
  /// once.
  public func load() async {
    switch phase {
    case .loading, .loaded: return
    case .idle, .failed:
      showCached()
      await loadFirstPage()
    }
  }

  /// The next page, when there is one and none is on its way.
  public func loadMore() async {
    guard phase == .loaded, hasMore, !isLoadingMore, !isReloadingPages else { return }
    isLoadingMore = true
    defer { isLoadingMore = false }
    let generation = generation
    do {
      let client = try client()
      let stores = AccountStores.current(session)
      let response = try await fetch(client, nextPage, itemsPerPage)
      guard generation == self.generation else { return }
      fetched += response.data
      showFetched()
      hasMore = response.hasMore && !response.data.isEmpty
      nextPage += 1
      pageError = nil
      keep(fetchedUnder: stores, firstPage: false)
    } catch {
      guard generation == self.generation, !Task.isCancelled else { return }
      pageError = APIError(error)
    }
  }

  /// Loads the next page when `item` is the last one shown.
  public func loadMore(after item: Item) async where Item: Identifiable {
    guard item.id == items.last?.id else { return }
    await loadMore()
  }

  /// Pull-to-refresh: the account and the people table, then page 1 in place of every page.
  public func refresh() async {
    if routed, !session.connectivity.isRouteAvailable {
      pageError = .noRoute
      if fetched.isEmpty { phase = .failed(.noRoute) }
      return
    }
    do {
      try await session.loadAccount()
    } catch {
      guard !Task.isCancelled else { return }
      pageError = APIError(error)
      if fetched.isEmpty { phase = .failed(APIError(error)) }
      return
    }
    await loadFirstPage()
  }

  private func loadFirstPage() async {
    await loadPages(through: 1)
  }

  /// Pages 1 through `last` in place of every page, stopping where the server has no more.
  private func loadPages(through last: Int) async {
    generation += 1
    let generation = generation
    isReloadingPages = true
    defer { if generation == self.generation { isReloadingPages = false } }
    if fetched.isEmpty { phase = .loading }
    let stores = AccountStores.current(session)
    observeAccount()
    do {
      let client = try client()
      var pages: [Item] = []
      var page = 1
      var more = true
      while more, page <= last {
        let response = try await fetch(client, page, itemsPerPage)
        guard generation == self.generation else { return }
        pages += response.data
        more = response.hasMore && !response.data.isEmpty
        page += 1
      }
      fetched = pages
      showFetched()
      hasMore = more
      nextPage = page
      pageError = nil
      lastUpdated = nil
      phase = .loaded
      keep(fetchedUnder: stores, firstPage: true)
    } catch {
      guard generation == self.generation else { return }
      if Task.isCancelled {
        if fetched.isEmpty { phase = .idle }
      } else if fetched.isEmpty {
        phase = .failed(APIError(error))
      } else if APIError(error) != .noRoute {
        pageError = APIError(error)
      }
    }
  }

  /// The first page if none was asked for, or every page shown again when what is shown is
  /// kept pages or a failure: for the page that owns a `routed` list, once a route appears, and
  /// for a list shown again, whose last read a cancelled task may have cut short behind the kept
  /// pages.
  public func rereadIfStale() async {
    switch phase {
    case .loading: return
    case .idle: return await load()
    case .failed: break
    case .loaded: guard lastUpdated != nil || pageError != nil else { return }
    }
    await loadPages(through: max(nextPage - 1, 1))
  }

  private func client() throws -> APIClient {
    try routed ? session.routedClient() : session.requireClient()
  }

  /// Joins the hub of the account the session names, and joins again each time the session
  /// comes to know its account: the first page after a sign-in is asked for before the account
  /// has loaded, when a phone new to the server has no account, and so no hub, to join.
  private func observeAccount() {
    if let stores = AccountStores.current(session) {
      OutboxHub.hub(for: stores.directory).observeLists(self)
      OutboxHub.hub(for: stores.directory).observe(self)
    }
    guard !watchesAccount else { return }
    watchesAccount = true
    withObservationTracking {
      _ = session.accountLoaded
    } onChange: { [weak self] in
      Task { @MainActor in
        self?.watchesAccount = false
        self?.observeAccount()
      }
    }
  }

  /// The kept pages alone, asking nothing: what a screen shows while it works out what to ask.
  func showKept() {
    showCached()
  }

  /// The kept pages, shown as loaded while page 1 is on its way. No more is asked for until
  /// it lands, so a later page never follows a stale one.
  private func showCached() {
    guard fetched.isEmpty, let cacheKey, let stores = AccountStores.current(session),
      let entry = stores.cache.pages(cacheKey.name, of: Item.self), !entry.value.items.isEmpty
    else { return }
    fetched = entry.value.items
    showFetched()
    hasMore = false
    lastUpdated = entry.fetchedAt
    phase = .loaded
  }

  private func showFetched() {
    guard let record = cacheKey?.record, let stores = AccountStores.current(session) else {
      items = fetched
      return
    }
    let gone = OutboxHub.hub(for: stores.directory).deleted.union(
      stores.outbox.items().filter { !$0.isFailed }.compactMap(\.operation.deletedRecord))
    items = gone.isEmpty ? fetched : fetched.filter { !gone.contains(record($0)) }
  }

  private func keep(fetchedUnder stores: AccountStores?, firstPage: Bool) {
    guard let cacheKey, let cache = cacheForAnswer(fetchedUnder: stores, session: session)
    else { return }
    cache.writePages(
      AccountCache.Pages(items: fetched, hasMore: hasMore, nextPage: nextPage), key: cacheKey.name)
    if firstPage, let number = cacheKey.highestDiveNumber?(fetched) {
      cache.setHighestDiveNumber(number)
    }
  }
}

extension PagedList: AccountStoresObserver {
  func accountStoresChanged() { showFetched() }
}

extension PagedList: ReloadingListObserver {
  func accountListsChanged() {
    guard phase != .idle else { return }
    reloading = Task { await loadPages(through: max(nextPage - 1, 1)) }
  }
}
