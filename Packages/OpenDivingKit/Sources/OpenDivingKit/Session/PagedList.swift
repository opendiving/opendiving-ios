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
  @ObservationIgnored private var nextPage = 1
  @ObservationIgnored private var generation = 0
  /// A refresh of a list already on screen leaves its items and its phase alone while its pages
  /// are on their way; a later page asked for in that window would be appended to the new ones.
  @ObservationIgnored private var isReloadingPages = false
  /// The reload a change to the account's records started.
  @ObservationIgnored var reloading: Task<Void, Never>?

  public init(
    session: Session, itemsPerPage: Int = APIClient.listPageSize,
    cache cacheKey: PageCacheKey<Item>? = nil, fetch: @escaping Fetch
  ) {
    self.session = session
    self.itemsPerPage = itemsPerPage
    self.cacheKey = cacheKey
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
      let client = try session.requireClient()
      let stores = AccountStores.current(session)
      let response = try await fetch(client, nextPage, itemsPerPage)
      guard generation == self.generation else { return }
      items += response.data
      hasMore = response.hasMore && !response.data.isEmpty
      nextPage += 1
      pageError = nil
      keep(fetchedUnder: stores, firstPage: false)
    } catch {
      guard generation == self.generation else { return }
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
    do {
      try await session.loadAccount()
    } catch {
      pageError = APIError(error)
      if items.isEmpty { phase = .failed(APIError(error)) }
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
    if items.isEmpty { phase = .loading }
    let stores = AccountStores.current(session)
    if let stores { OutboxHub.hub(for: stores.directory).observeLists(self) }
    do {
      let client = try session.requireClient()
      var fetched: [Item] = []
      var page = 1
      var more = true
      while more, page <= last {
        let response = try await fetch(client, page, itemsPerPage)
        guard generation == self.generation else { return }
        fetched += response.data
        more = response.hasMore && !response.data.isEmpty
        page += 1
      }
      items = fetched
      hasMore = more
      nextPage = page
      pageError = nil
      lastUpdated = nil
      phase = .loaded
      keep(fetchedUnder: stores, firstPage: true)
    } catch {
      guard generation == self.generation else { return }
      if items.isEmpty {
        phase = .failed(APIError(error))
      } else {
        pageError = APIError(error)
      }
    }
  }

  /// The kept pages, shown as loaded while page 1 is on its way. No more is asked for until
  /// it lands, so a later page never follows a stale one.
  private func showCached() {
    guard items.isEmpty, let cacheKey, let stores = AccountStores.current(session),
      let entry = stores.cache.pages(cacheKey.name, of: Item.self), !entry.value.items.isEmpty
    else { return }
    items = entry.value.items
    hasMore = false
    lastUpdated = entry.fetchedAt
    phase = .loaded
  }

  private func keep(fetchedUnder stores: AccountStores?, firstPage: Bool) {
    guard let cacheKey, let cache = cacheForAnswer(fetchedUnder: stores, session: session)
    else { return }
    cache.writePages(
      AccountCache.Pages(items: items, hasMore: hasMore, nextPage: nextPage), key: cacheKey.name)
    if firstPage, let number = cacheKey.highestDiveNumber?(items) {
      cache.setHighestDiveNumber(number)
    }
  }
}

extension PagedList: AccountListsObserver {
  func accountListsChanged() {
    guard phase != .idle else { return }
    reloading = Task { await loadPages(through: max(nextPage - 1, 1)) }
  }
}
