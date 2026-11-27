import Foundation
import Observation

/// One dive site as the sites map's panel shows it: the site, every dive there a page at a time,
/// and the species seen on them with their photos.
///
/// A site the phone has opened before shows at once from the account's cache, its dives and
/// species with it, under ``lastUpdated``, while it is fetched behind; a fetch that fails leaves
/// it standing. With no route nothing is asked for, and ``followRoute()`` reads again once one
/// appears. A 404 for the site means the server no longer has it, and the phone forgets it.
@MainActor
@Observable
public final class DiveSiteDetailModel: AccountStoresObserver, ReloadingListObserver {
  public let siteUUID: UUID
  public private(set) var phase: DetailPhase<DiveSiteRead> = .loading
  /// When the phone's copy on screen was fetched, until a read lands in its place: the line
  /// saying how old it is stands while that read is on its way, and through one that fails.
  public var lastUpdated: Date? { fetchedAt }
  /// When the cache's copy on screen was fetched; nil once this visit's read has landed.
  private var fetchedAt: Date?
  public let dives: PagedList<DiveListItem>
  public private(set) var species: SpeciesSeen = .none
  public let photos: SpeciesCardPhotos
  /// A Commons record's history where the server edits the Commons: empty until this visit's
  /// read lands, and empty when it fails. Kept in no cache, so a name taken off, renamed or
  /// deleted is gone on the next open.
  public private(set) var history: [DiveSiteHistoryEntryRead] = []

  /// The queue holds an edit of this site, which the panel shows once it lands.
  public private(set) var hasPendingEdit = false
  /// The *Withdraw* on the panel's proposal notice.
  public let withdrawal: ProposalWithdrawal
  /// The *Replace with Commons site* on the panel's match notice.
  public let replacement: CommonsSiteReplacement

  @ObservationIgnored private let session: Session
  /// The last read of the site was skipped for want of a route.
  @ObservationIgnored private var skippedForRoute = false
  /// The read a queued edit landing started.
  @ObservationIgnored var reloading: Task<Void, Never>?

  public init(session: Session, siteUUID: UUID) {
    self.session = session
    self.siteUUID = siteUUID
    photos = SpeciesCardPhotos(session: session)
    withdrawal = ProposalWithdrawal(session: session)
    replacement = CommonsSiteReplacement(session: session)
    dives = PagedList(
      session: session, itemsPerPage: APIClient.nestedListPageSize, cache: .siteDives(siteUUID),
      routed: true
    ) { client, page, itemsPerPage in
      try await client.dives(page: page, itemsPerPage: itemsPerPage, diveSiteUUID: siteUUID)
    }
  }

  /// The site, then its dives and its species; nothing once the site is on screen.
  public func load() async {
    if phase.isLoaded { return }
    showCached()
    await readSite()
    guard case .loaded(let site) = phase else { return }
    async let list: Void = dives.load()
    async let seen: Void = readSpecies(site)
    async let changes: Void = readHistory(site)
    _ = await (list, seen, changes)
  }

  /// Takes back the diver's proposal on the site and reads the site again.
  public func withdraw(_ proposal: UUID) async {
    await withdrawal.withdraw(proposal) { await reloadWithEveryList(on: session) }
  }

  /// Replaces the site with the Commons record, answering the record the panel gives way to; nil
  /// with the reason on ``replacement``.
  public func replace(with record: UUID) async -> DiveSiteRead? {
    await replacement.replace(siteUUID, with: record) { await reloadWithEveryList(on: session) }
  }

  /// Reads again what a route can mend — now, if a read was skipped for want of one that has
  /// since appeared, and each time one appears — until the calling task is cancelled.
  public func followRoute() async {
    if skippedForRoute, session.connectivity.isRouteAvailable { await reread() }
    await session.connectivity.eachRouteAppearance { await reread() }
  }

  func reread() async {
    let stale =
      switch phase {
      case .loaded: fetchedAt != nil
      case .failed: true
      case .loading, .notFound: false
      }
    if stale { await readSite() }
    guard case .loaded(let site) = phase else { return }
    let speciesStale = stale || species == .failed
    async let list: Void = dives.rereadIfStale()
    if speciesStale { await readSpecies(site) }
    if stale { await readHistory(site) }
    await list
  }

  private func showCached() {
    guard let stores = AccountStores.current(session), let entry = stores.cache.site(siteUUID)
    else { return }
    if stores.loaded { stores.cache.touchSite(siteUUID) }
    fetchedAt = entry.fetchedAt
    phase = .loaded(entry.value.site)
    if entry.value.site.speciesCount > 0, let entries = entry.value.species {
      species = .loaded(entries)
    }
    watchStores()
  }

  private func readSite() async {
    let wasLoaded = phase.isLoaded
    if !wasLoaded { phase = .loading }
    let stores = AccountStores.current(session)
    do {
      let site = try await session.routedClient().diveSite(siteUUID)
      skippedForRoute = false
      fetchedAt = nil
      phase = .loaded(site)
      keep(site, fetchedUnder: stores)
      watchStores()
    } catch {
      skippedForRoute = APIError(error) == .noRoute
      let next = DetailPhase<DiveSiteRead>.failure(error)
      if next == .notFound {
        cacheForAnswer(fetchedUnder: stores, session: session)?.removeSite(siteUUID)
        fetchedAt = nil
      }
      if !wasLoaded || next == .notFound { phase = next }
    }
  }

  /// Writes `site` with the species on screen, or those kept while they have not loaded.
  private func keep(_ site: DiveSiteRead, fetchedUnder stores: AccountStores?) {
    guard let cache = cacheForAnswer(fetchedUnder: stores, session: session) else { return }
    let entries: [SpeciesLifeListEntry]? =
      if case .loaded(let entries) = species { entries } else {
        cache.site(siteUUID)?.value.species
      }
    cache.writeSite(AccountCache.Site(site: site, species: entries), fetchedAt: Date())
  }

  private func watchStores() {
    guard let stores = AccountStores.current(session) else { return }
    let hub = OutboxHub.hub(for: stores.directory)
    hub.observe(self)
    hub.observeLists(self)
    accountStoresChanged()
  }

  func accountStoresChanged() {
    let ref = RecordRef.server(siteUUID)
    hasPendingEdit =
      AccountStores.current(session)?.outbox.items().contains { item in
        if case .updateDiveSite(ref, _) = item.operation { !item.isFailed } else { false }
      } ?? false
  }

  /// A write landed, perhaps this site's edit: the panel reads the site again. Its dives are a
  /// list, which reads itself.
  func accountListsChanged() {
    guard phase.isLoaded else { return }
    reloading = Task { await readSite() }
  }

  /// Read whole, as the web reads it, once the server has said it edits the Commons.
  private func readHistory(_ site: DiveSiteRead) async {
    guard site.isCommons else { return }
    await session.loadServerInfo()
    guard session.isCommonsPrimary else { return }
    let siteUUID = siteUUID
    do {
      let client = try session.routedClient()
      history = try await APIClient.allPages { page, itemsPerPage in
        try await client.diveSiteHistory(siteUUID, page: page, itemsPerPage: itemsPerPage)
      }
    } catch {
      history = []
    }
  }

  /// Read whole, as the web reads it: a site's species are a list worth seeing entire.
  private func readSpecies(_ site: DiveSiteRead) async {
    guard site.speciesCount > 0 else {
      species = .none
      return
    }
    if case .loaded = species {} else { species = .loading }
    let siteUUID = siteUUID
    let stores = AccountStores.current(session)
    do {
      let client = try session.routedClient()
      let entries = try await APIClient.allPages { page, itemsPerPage in
        try await client.speciesLifeList(
          diveSiteUUID: siteUUID, page: page, itemsPerPage: itemsPerPage)
      }
      species = .loaded(entries)
      if case .loaded(let shown) = phase, fetchedAt == nil {
        keep(shown, fetchedUnder: stores)
      }
    } catch {
      if case .loaded = species { return }
      species = .failed
    }
  }
}
