import Foundation
import Observation

/// One of More's record pages, as far as the record goes: a gear item, a course, a
/// certification, a person or a species. The lists the page shows beside it are
/// ``PagedList``s under the keys its ``KeptRecordKind`` drops with it.
///
/// A record the phone has shown before shows at once from the account's cache while it is
/// fetched behind; a fetch that fails leaves it standing, under ``lastUpdated``. With no
/// route nothing is asked for, and ``followRoute()`` reads again once one appears. A 404 means
/// the server no longer has the record: the phone forgets it with its lists, and every list on
/// screen leaves its row out at once. A write that
/// lands reads it again; one still queued shows as ``hasPendingEdit``.
@MainActor
@Observable
public final class RecordPage<Record: Codable & Hashable & Sendable> {
  public typealias Fetch = @Sendable (_ client: APIClient, _ uuid: UUID) async throws -> Record

  public let uuid: UUID
  public private(set) var phase: DetailPhase<Record> = .loading
  /// When the record shown was fetched, once it is the cache's and no read of this visit's is on
  /// its way: offline, or after the read behind it failed. A read that lands replaces it with
  /// nothing to say, so the line saying how old it is would show only to go again.
  public var lastUpdated: Date? { isReading ? nil : fetchedAt }
  /// When the cache's copy on screen was fetched; nil once this visit's read has landed.
  private(set) var fetchedAt: Date?
  /// A read is on its way.
  private var isReading = false
  /// The queue holds a change to this record, which the page shows once it lands.
  public private(set) var hasPendingEdit = false

  @ObservationIgnored private let session: Session
  @ObservationIgnored private let kind: KeptRecordKind<Record>
  @ObservationIgnored private let fetch: Fetch
  /// The last read was skipped for want of a route.
  @ObservationIgnored private var skippedForRoute = false
  /// The read a landed write started.
  @ObservationIgnored var reloading: Task<Void, Never>?

  public init(
    session: Session, kind: KeptRecordKind<Record>, uuid: UUID, fetch: @escaping Fetch
  ) {
    self.session = session
    self.kind = kind
    self.uuid = uuid
    self.fetch = fetch
  }

  /// The kept copy at once, then the server's; nothing once the record is on screen.
  public func load() async {
    watchStores()
    if phase.isLoaded { return }
    showCached()
    await read()
  }

  /// Pull-to-refresh. A record already on screen stays there when the refresh fails.
  public func refresh() async {
    await read()
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
    if stale { await read() }
  }

  private func showCached() {
    guard let stores = AccountStores.current(session), let entry = stores.cache.record(kind, uuid)
    else { return }
    if stores.loaded { stores.cache.touchRecord(kind, uuid) }
    fetchedAt = entry.fetchedAt
    phase = .loaded(entry.value)
    observeLists()
  }

  private func read() async {
    let wasLoaded = phase.isLoaded
    if !wasLoaded { phase = .loading }
    let stores = AccountStores.current(session)
    isReading = true
    defer { isReading = false }
    do {
      let record = try await fetch(session.routedClient(), uuid)
      skippedForRoute = false
      fetchedAt = nil
      phase = .loaded(record)
      cacheForAnswer(fetchedUnder: stores, session: session)?.writeRecord(
        record, kind, fetchedAt: Date())
      observeLists()
    } catch {
      skippedForRoute = APIError(error) == .noRoute
      let next = DetailPhase<Record>.failure(error)
      if !wasLoaded || next == .notFound { phase = next }
      if next == .notFound {
        fetchedAt = nil
        // After the phase, so the lists' signal does not send this page reading again.
        storesForAnswer(fetchedUnder: stores, session: session)?.forgetRecord(kind, uuid)
      }
    }
  }

  private func watchStores() {
    guard let stores = AccountStores.current(session) else { return }
    OutboxHub.hub(for: stores.directory).observe(self)
    accountStoresChanged()
  }

  private func observeLists() {
    guard let stores = AccountStores.current(session) else { return }
    OutboxHub.hub(for: stores.directory).observeLists(self)
  }
}

extension RecordPage: AccountStoresObserver {
  func accountStoresChanged() {
    let ref = RecordRef.server(uuid)
    hasPendingEdit =
      AccountStores.current(session)?.outbox.items().contains { item in
        item.operation.target == ref && item.operation.deletedRecordRef == nil && !item.isFailed
      } ?? false
  }
}

extension RecordPage: AccountListsObserver {
  /// A write landed, perhaps to this record: the page reads it again.
  func accountListsChanged() {
    guard phase.isLoaded else { return }
    reloading = Task { await read() }
  }
}

extension RecordPage where Record == GearItemRead {
  public convenience init(session: Session, gearItem uuid: UUID) {
    self.init(session: session, kind: .gearItem, uuid: uuid) { try await $0.gearItem($1) }
  }
}

extension RecordPage where Record == CourseRead {
  public convenience init(session: Session, course uuid: UUID) {
    self.init(session: session, kind: .course, uuid: uuid) { try await $0.course($1) }
  }
}

extension RecordPage where Record == CertificationRead {
  public convenience init(session: Session, certification uuid: UUID) {
    self.init(session: session, kind: .certification, uuid: uuid) {
      try await $0.certification($1)
    }
  }
}

extension RecordPage where Record == PersonRead {
  public convenience init(session: Session, person uuid: UUID) {
    self.init(session: session, kind: .person, uuid: uuid) { try await $0.person($1) }
  }
}

extension RecordPage where Record == SpeciesPage {
  public convenience init(session: Session, species uuid: UUID) {
    self.init(session: session, kind: .species, uuid: uuid) {
      try await SpeciesPage.read($1, client: $0)
    }
  }
}
