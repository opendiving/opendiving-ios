import Observation

/// One paginated list as a screen shows it: the first page on appear, the next on reaching
/// the end while the server says there is more, and pull-to-refresh, which reloads the
/// account and the people table before page 1 — every list a screen draws names people.
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

  @ObservationIgnored private let session: Session
  @ObservationIgnored private let itemsPerPage: Int
  @ObservationIgnored private let fetch: Fetch
  @ObservationIgnored private var nextPage = 1
  @ObservationIgnored private var generation = 0
  /// A refresh of a list already on screen leaves its items and its phase alone while page 1
  /// is on its way; a later page asked for in that window would be appended to the new page 1.
  @ObservationIgnored private var isLoadingFirstPage = false

  public init(session: Session, itemsPerPage: Int = APIClient.listPageSize, fetch: @escaping Fetch)
  {
    self.session = session
    self.itemsPerPage = itemsPerPage
    self.fetch = fetch
  }

  /// The first page, unless it is loaded or loading already.
  public func load() async {
    switch phase {
    case .loading, .loaded: return
    case .idle, .failed: await loadFirstPage()
    }
  }

  /// The next page, when there is one and none is on its way.
  public func loadMore() async {
    guard phase == .loaded, hasMore, !isLoadingMore, !isLoadingFirstPage else { return }
    isLoadingMore = true
    defer { isLoadingMore = false }
    let generation = generation
    do {
      let client = try session.requireClient()
      let response = try await fetch(client, nextPage, itemsPerPage)
      guard generation == self.generation else { return }
      items += response.data
      hasMore = response.hasMore && !response.data.isEmpty
      nextPage += 1
      pageError = nil
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
    generation += 1
    let generation = generation
    isLoadingFirstPage = true
    defer { if generation == self.generation { isLoadingFirstPage = false } }
    if items.isEmpty { phase = .loading }
    do {
      let client = try session.requireClient()
      let response = try await fetch(client, 1, itemsPerPage)
      guard generation == self.generation else { return }
      items = response.data
      hasMore = response.hasMore && !response.data.isEmpty
      nextPage = 2
      pageError = nil
      phase = .loaded
    } catch {
      guard generation == self.generation else { return }
      if items.isEmpty {
        phase = .failed(APIError(error))
      } else {
        pageError = APIError(error)
      }
    }
  }
}
