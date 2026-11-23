import Foundation
import Observation

/// One paginated list as a screen shows it: the first page on appear, the next on reaching
/// the end while the server says there is more, and pull-to-refresh, which reloads the
/// account and the people table before page 1 — every list a screen draws names people.
///
/// Given a cache key, the pages it loads are kept for the account, and on appear the kept
/// pages show at once while page 1 is fetched behind them; a fetch that fails leaves them
/// standing, under ``lastUpdated``. Nothing waits for a request to fail before showing what the
/// phone has, since a request waits a minute for a route — except a list loaded behind another
/// still on screen, ``loadKeptOnFailure()``. A page is written only once the account has loaded
/// in this process, so another account's answer never lands in the previous one's cache.
///
/// A list that has loaded fetches every page it shows again, behind the items shown, when the
/// account's records change under it — an import applied, a queued write landed — rather than
/// waiting for a pull, and rather than dropping back to page 1 under a diver scrolled past it.
///
/// A list that names its rows' records leaves out a record whose delete is queued, offline too,
/// and shows it again if the delete is discarded or refused; and, at once, one the server no
/// longer has, until a page fetched since names it again.
///
/// A list made `routed` asks for nothing while the phone believes it has no route: it fails at
/// once with ``APIError/noRoute``, quietly behind kept pages, and the page that owns it reads
/// again when one appears.
///
/// A load whose task is cancelled has no outcome: nothing it shows says it failed, and a list
/// with nothing fetched is idle again, so the next ``load()`` asks once more.
///
/// A list made `readsEveryPage` goes on to its last page after every load that lands, for a
/// screen that needs the whole list at once — an index of its letters — rather than the pages
/// scrolled to. It stops at a page that fails, and the next load picks up from there.
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
  /// How many rows the list holds in all, as its latest page says, less those being deleted;
  /// nil until a page shows.
  public var count: Int? {
    guard phase == .loaded else { return nil }
    return (totalCount ?? fetched.count) - (fetched.count - items.count)
  }
  /// A later page, or a refresh, failed while earlier items stay on screen.
  public private(set) var pageError: APIError? = nil
  /// When the kept pages shown were fetched, once no read a route may answer is on its way:
  /// offline, or after the read behind them failed. A read that lands replaces them with nothing
  /// to say, so the line saying how old they are would show only to go again.
  public var lastUpdated: Date? { isReading ? nil : fetchedAt }
  /// When the items shown were fetched, while they are the cache's rather than this visit's.
  private(set) var fetchedAt: Date? = nil
  /// When the read behind the items shown began, once one has landed: they are what the server
  /// held then or later.
  private(set) var readSince: Date? = nil
  /// The server's count of every row, from the latest page read.
  private var totalCount: Int? = nil
  /// A read of every page is on its way, begun while the phone believed it had a route.
  private var isReading = false

  @ObservationIgnored private let session: Session
  @ObservationIgnored private let itemsPerPage: Int
  @ObservationIgnored private let fetch: Fetch
  @ObservationIgnored private let cacheKey: PageCacheKey<Item>?
  @ObservationIgnored private let routed: Bool
  @ObservationIgnored private let readsEveryPage: Bool
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
    cache cacheKey: PageCacheKey<Item>? = nil, routed: Bool = false, readsEveryPage: Bool = false,
    fetch: @escaping Fetch
  ) {
    self.session = session
    self.itemsPerPage = itemsPerPage
    self.cacheKey = cacheKey
    self.routed = routed
    self.readsEveryPage = readsEveryPage
    self.fetch = fetch
  }

  /// The first page, unless it is loaded or loading already — after the kept pages, shown at
  /// once. A list that reads every page reads as many as it kept before it shows any again.
  public func load() async {
    switch phase {
    case .loading, .loaded: return
    case .idle, .failed:
      showCached()
      await loadPages(through: max(nextPage - 1, 1))
    }
  }

  /// The next page, when there is one and none is on its way — and every page after it, for a
  /// list that reads every page.
  public func loadMore() async {
    await loadNextPage()
    await readRest()
  }

  /// Every page still to come for a list that reads every page, until one fails. A load already
  /// holding the list leaves it alone, since that load reads the rest once it lands.
  private func readRest() async {
    guard readsEveryPage else { return }
    while hasMore, pageError == nil, !Task.isCancelled {
      let page = nextPage
      await loadNextPage()
      guard nextPage > page else { return }
    }
  }

  private func loadNextPage() async {
    guard phase == .loaded, hasMore, !isLoadingMore, !isReloadingPages else { return }
    isLoadingMore = true
    let generation = generation
    // A reload that began meanwhile has taken the flag back, and may be loading a page of its own.
    defer { if generation == self.generation { isLoadingMore = false } }
    do {
      let client = try client()
      let stores = AccountStores.current(session)
      let began = Date()
      let response = try await fetch(client, nextPage, itemsPerPage)
      guard generation == self.generation else { return }
      fetched += response.data
      takeBack(response.data, fetchedSince: began, under: stores)
      totalCount = response.totalCount
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
    await refresh(sharing: AccountReload(session: session))
  }

  /// ``refresh()`` as one of the lists a page's pull refreshes together, which read the account
  /// once between them.
  func refresh(sharing account: AccountReload) async {
    if routed, !session.connectivity.isRouteAvailable {
      pageError = .noRoute
      if fetched.isEmpty { phase = .failed(.noRoute) }
      return
    }
    do {
      try await account.run()
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

  /// Pages 1 through `last` in place of every page, stopping where the server has no more, then
  /// the rest for a list that reads every page.
  private func loadPages(through last: Int) async {
    await readPages(through: last)
    await readRest()
  }

  private func readPages(through last: Int) async {
    let began = Date()
    generation += 1
    let generation = generation
    // A later page on its way belongs to the pages this replaces, and is dropped when it lands.
    isLoadingMore = false
    isReloadingPages = true
    isReading = session.connectivity.isRouteAvailable
    defer {
      if generation == self.generation {
        isReloadingPages = false
        isReading = false
      }
    }
    if fetched.isEmpty { phase = .loading }
    let stores = AccountStores.current(session)
    observeAccount()
    do {
      let client = try client()
      var pages: [Item] = []
      var page = 1
      var more = true
      var total: Int?
      while more, page <= last {
        let response = try await fetch(client, page, itemsPerPage)
        guard generation == self.generation else { return }
        pages += response.data
        total = response.totalCount
        more = response.hasMore && !response.data.isEmpty
        page += 1
      }
      fetched = pages
      takeBack(pages, fetchedSince: began, under: stores)
      totalCount = total
      showFetched()
      hasMore = more
      nextPage = page
      pageError = nil
      fetchedAt = nil
      readSince = began
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
  /// pages. A list that reads every page and is fresh reads the pages a cancelled task left
  /// unread.
  public func rereadIfStale() async {
    switch phase {
    case .loading: return
    case .idle: return await load()
    case .failed: break
    case .loaded: guard fetchedAt != nil || pageError != nil else { return await readRest() }
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

  /// The first page with nothing kept shown while it is on its way, and the kept pages once it
  /// fails: for a list that waits behind another on screen until it can take its place.
  func loadKeptOnFailure() async {
    switch phase {
    case .loading, .loaded: return
    case .idle, .failed: await loadFirstPage()
    }
    guard case .failed(let error) = phase else { return }
    showCached()
    if phase == .loaded, error != .noRoute { pageError = error }
  }

  /// Puts `item` in place of the row with its id: an answer the screen had from a write of its
  /// own.
  func replace(_ item: Item) where Item: Identifiable {
    guard let index = fetched.firstIndex(where: { $0.id == item.id }) else { return }
    fetched[index] = item
    showFetched()
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
    totalCount = entry.value.totalCount
    showFetched()
    hasMore = false
    // Which page comes next is no concern of a list that reads only page 1 again.
    if readsEveryPage { nextPage = entry.value.nextPage }
    fetchedAt = entry.fetchedAt
    phase = .loaded
  }

  private func showFetched() {
    guard let record = cacheKey?.record, let stores = AccountStores.current(session) else {
      items = fetched
      return
    }
    let gone = Set(OutboxHub.hub(for: stores.directory).deleted.keys).union(
      stores.outbox.items().filter { !$0.isFailed }.compactMap(\.operation.deletedRecord))
    items = gone.isEmpty ? fetched : fetched.filter { !gone.contains(record($0)) }
  }

  /// What a page fetched since the server said a record was gone still names is back, in every
  /// list: imported again under its uuid.
  private func takeBack(_ page: [Item], fetchedSince began: Date, under stores: AccountStores?) {
    guard let record = cacheKey?.record, let stores else { return }
    OutboxHub.hub(for: stores.directory).named(page.map(record), fetchedSince: began)
  }

  private func keep(fetchedUnder stores: AccountStores?, firstPage: Bool) {
    guard let cacheKey, let cache = cacheForAnswer(fetchedUnder: stores, session: session)
    else { return }
    cache.writePages(
      AccountCache.Pages(
        items: fetched, hasMore: hasMore, nextPage: nextPage, totalCount: totalCount),
      key: cacheKey.name)
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
