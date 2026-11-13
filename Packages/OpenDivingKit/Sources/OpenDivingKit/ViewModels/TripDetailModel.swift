import Foundation
import Observation

/// One trip's page: the trip, its own dives a page at a time, and the contacts its
/// information card names — each part's accommodation and the trip's dive centres.
///
/// A trip the phone has opened before shows at once from the account's cache, its dives and
/// contacts with it, while it is fetched behind; a fetch that fails leaves it standing, under
/// ``lastUpdated``. With no route nothing is asked for, and ``followRoute()`` reads again once one
/// appears. A 404 for the trip means the server no longer has it, and the phone forgets it.
@MainActor
@Observable
public final class TripDetailModel: AccountStoresObserver, AccountListsObserver {
  public let tripUUID: UUID
  public private(set) var phase: DetailPhase<TripRead> = .loading
  /// When the trip shown was fetched, once it is the cache's and no read of this visit's is on
  /// its way: offline, or after the read behind it failed. A read that lands replaces it with
  /// nothing to say, so the line saying how old it is would show only to go again.
  public var lastUpdated: Date? { isReading ? nil : fetchedAt }
  /// When the cache's copy on screen was fetched; nil once this visit's read has landed.
  private(set) var fetchedAt: Date?
  /// A read is on its way.
  private var isReading = false
  /// The contacts read so far, by uuid. One that failed to read is left out, and the card
  /// draws the part or the line without it.
  public private(set) var contacts: [UUID: ContactRead] = [:]
  /// The trip's own dives, newest first. Candidates — dives on no trip whose day a part
  /// covers — are not among them.
  public let dives: PagedList<DiveListItem>

  /// The queue holds an edit of this trip, which the page shows once it lands.
  public private(set) var hasPendingEdit = false

  @ObservationIgnored private let session: Session
  /// The last read of the trip was skipped for want of a route.
  @ObservationIgnored private var skippedForRoute = false
  /// The read a queued edit landing started.
  @ObservationIgnored var reloading: Task<Void, Never>?

  public init(session: Session, tripUUID: UUID) {
    self.session = session
    self.tripUUID = tripUUID
    dives = PagedList(
      session: session, itemsPerPage: APIClient.nestedListPageSize, cache: .tripDives(tripUUID),
      routed: true
    ) { client, page, itemsPerPage in
      try await client.dives(page: page, itemsPerPage: itemsPerPage, tripUUID: tripUUID)
    }
  }

  /// The trip, then its dives and its contacts; nothing once the trip is on screen.
  public func load() async {
    if case .loaded = phase { return }
    showCached()
    await readTrip()
    guard case .loaded(let trip) = phase else { return }
    async let list: Void = dives.load()
    async let names: Void = readContacts(trip)
    _ = await (list, names)
  }

  /// Pull-to-refresh: the trip, its dives from the first page, and its contacts again. A
  /// trip already on screen stays there when the refresh fails.
  public func refresh() async {
    await readTrip()
    guard case .loaded(let trip) = phase else { return }
    async let list: Void = dives.refresh()
    async let names: Void = readContacts(trip)
    _ = await (list, names)
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
    if stale { await readTrip() }
    guard case .loaded(let trip) = phase else { return }
    async let list: Void = dives.rereadIfStale()
    if stale { await readContacts(trip) }
    await list
  }

  private func showCached() {
    guard let stores = AccountStores.current(session), let entry = stores.cache.trip(tripUUID)
    else { return }
    if stores.loaded { stores.cache.touchTrip(tripUUID) }
    fetchedAt = entry.fetchedAt
    phase = .loaded(entry.value.trip)
    contacts = Dictionary(entry.value.contacts.map { ($0.uuid, $0) }) { _, last in last }
    watchStores()
  }

  private func readTrip() async {
    let wasLoaded = phase.isLoaded
    if !wasLoaded { phase = .loading }
    let stores = AccountStores.current(session)
    isReading = true
    defer { isReading = false }
    do {
      let trip = try await session.routedClient().trip(tripUUID)
      skippedForRoute = false
      fetchedAt = nil
      phase = .loaded(trip)
      keep(trip, fetchedUnder: stores)
      watchStores()
    } catch {
      skippedForRoute = APIError(error) == .noRoute
      let next = DetailPhase<TripRead>.failure(error)
      if next == .notFound {
        cacheForAnswer(fetchedUnder: stores, session: session)?.removeTrip(tripUUID)
        fetchedAt = nil
      }
      if !wasLoaded || next == .notFound { phase = next }
    }
  }

  /// Writes `trip` with the contacts it names that have been read.
  private func keep(_ trip: TripRead, fetchedUnder stores: AccountStores?) {
    guard let cache = cacheForAnswer(fetchedUnder: stores, session: session) else { return }
    let named = TripSummary.contactUUIDs(trip).compactMap { contacts[$0] }
    cache.writeTrip(AccountCache.Trip(trip: trip, contacts: named), fetchedAt: Date())
  }

  private func watchStores() {
    guard let stores = AccountStores.current(session) else { return }
    let hub = OutboxHub.hub(for: stores.directory)
    hub.observe(self)
    hub.observeLists(self)
    accountStoresChanged()
  }

  func accountStoresChanged() {
    let ref = RecordRef.server(tripUUID)
    hasPendingEdit =
      AccountStores.current(session)?.outbox.items().contains { item in
        if case .updateTrip(ref, _) = item.operation { !item.isFailed } else { false }
      } ?? false
  }

  /// A write landed, perhaps this trip's edit: the page reads the trip again. Its dives are a
  /// list, which reads itself.
  func accountListsChanged() {
    guard phase.isLoaded else { return }
    reloading = Task {
      await readTrip()
      if case .loaded(let trip) = phase { await readContacts(trip) }
    }
  }

  private func readContacts(_ trip: TripRead) async {
    guard let client = try? session.routedClient() else { return }
    let stores = AccountStores.current(session)
    let uuids = TripSummary.contactUUIDs(trip)
    let read = await withTaskGroup(of: ContactRead?.self) { group in
      for uuid in uuids {
        group.addTask { try? await client.contact(uuid) }
      }
      var read: [UUID: ContactRead] = [:]
      for await contact in group {
        if let contact { read[contact.uuid] = contact }
      }
      return read
    }
    // Merged, so a refresh that cannot reach one keeps the name already shown.
    contacts.merge(read) { _, new in new }
    if case .loaded(let shown) = phase, fetchedAt == nil { keep(shown, fetchedUnder: stores) }
  }
}
