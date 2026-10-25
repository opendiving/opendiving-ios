import Foundation
import Observation

/// One dive's page as it loads: the dive, then what it names — its trip, its course, its
/// dive centre and the dives either side — each of which may fail without failing the page,
/// as the web hides a link it could not resolve.
///
/// A dive the phone has opened before shows at once from the account's cache, under
/// ``lastUpdated``, while it is fetched behind; a fetch that fails leaves it standing. While
/// the queue holds an edit of the dive that has not failed, the edit's values are laid over it
/// and ``hasPendingEdit`` says so, until the flush reads the dive back.
@MainActor
@Observable
public final class DiveDetailModel: AccountStoresObserver {
  public enum Phase: Equatable, Sendable {
    case loading
    case loaded(DiveReadWithMixtures)
    case failed(APIError)
  }

  /// The dive asked for: the one on screen, or the one the pager is stepping to. What is on
  /// screen is the loaded dive's own uuid.
  public private(set) var diveUUID: UUID
  public private(set) var phase: Phase = .loading
  public private(set) var trip: TripRead?
  public private(set) var course: CourseRead?
  public private(set) var contact: ContactRead?
  public private(set) var neighbors: DiveNeighbors?
  /// A step of the pager is on its way; the dive being left stays on screen until it lands.
  public private(set) var isStepping = false
  /// When the dive shown was fetched, while it is the cache's rather than this visit's.
  public private(set) var lastUpdated: Date?
  /// Why the fetch behind a cached dive failed; the cached dive stays on screen.
  public private(set) var refreshError: APIError?
  /// The queue holds an edit of this dive, which the dive shown already carries.
  public private(set) var hasPendingEdit = false

  @ObservationIgnored private let session: Session
  @ObservationIgnored private var generation = 0
  /// The dive as the server or the cache gave it, before any queued edit.
  @ObservationIgnored private var base: DiveReadWithMixtures?
  /// When the server answered `base`, so a newer copy in the cache replaces it.
  @ObservationIgnored private var baseAt = Date.distantPast

  public init(session: Session, diveUUID: UUID) {
    self.session = session
    self.diveUUID = diveUUID
  }

  /// The dive on screen, queued edits included: what the edit form starts from.
  public var dive: DiveReadWithMixtures? {
    if case .loaded(let dive) = phase { dive } else { nil }
  }

  /// The page's content in the account's units, once the dive has loaded.
  public var content: DiveDetailContent? {
    guard case .loaded(let dive) = phase else { return nil }
    return DiveDetailContent(
      dive: dive, trip: trip, course: course, contact: contact, people: session.people,
      units: session.units)
  }

  /// Loads the dive this model was opened on, or retries it.
  public func load() async {
    await load(diveUUID)
  }

  /// Steps to a neighbouring dive in place.
  public func show(_ uuid: UUID) async {
    guard uuid != diveUUID else { return }
    await load(uuid)
  }

  /// The species' photo, or nil when it cannot be had; the card then draws its backdrop.
  public func speciesPhoto(_ uuid: UUID, version: String) async -> Data? {
    guard let client = try? session.requireClient() else { return nil }
    return try? await client.speciesPhoto(uuid, version: version).data
  }

  private func load(_ uuid: UUID) async {
    generation += 1
    let generation = generation
    diveUUID = uuid
    neighbors = nil
    refreshError = nil
    let fromCache = showCached(uuid)
    if !fromCache {
      if case .loaded = phase { isStepping = true } else { phase = .loading }
    }
    defer { if generation == self.generation { isStepping = false } }

    let stores = AccountStores.current(session)
    let client: APIClient
    let dive: DiveReadWithMixtures
    do {
      client = try session.requireClient()
      dive = try await client.dive(uuid)
    } catch {
      guard generation == self.generation else { return }
      if fromCache {
        refreshError = APIError(error)
      } else {
        phase = .failed(APIError(error))
      }
      return
    }
    guard generation == self.generation else { return }
    if !fromCache { (trip, course, contact) = (nil, nil, nil) }
    lastUpdated = nil
    let answeredAt = Date()
    show(dive, at: answeredAt)
    isStepping = false

    async let trip = dive.tripUuid.asyncMap { try? await client.trip($0) }
    async let course = dive.courseUuid.asyncMap { try? await client.course($0) }
    async let contact = dive.contactUuid.asyncMap { try? await client.contact($0) }
    async let neighbors = try? await client.neighbors(ofDive: uuid)
    let related = await (trip, course, contact, neighbors)
    guard generation == self.generation else { return }
    (self.trip, self.course, self.contact) = (related.0 ?? nil, related.1 ?? nil, related.2 ?? nil)
    self.neighbors = related.3
    // A landed edit read back while the cards loaded is newer than this answer, and stays.
    guard let cache = cacheForAnswer(fetchedUnder: stores, session: session),
      (cache.dive(uuid)?.fetchedAt ?? .distantPast) <= answeredAt
    else { return }
    cache.writeDive(
      AccountCache.Dive(dive: dive, trip: self.trip, course: self.course, contact: self.contact),
      fetchedAt: answeredAt)
  }

  /// Shows the cached copy of `uuid`, if the phone holds one.
  private func showCached(_ uuid: UUID) -> Bool {
    guard let stores = AccountStores.current(session),
      let entry = stores.cache.dive(uuid)
    else {
      lastUpdated = nil
      return false
    }
    if stores.loaded { stores.cache.touchDive(uuid) }
    (trip, course, contact) = (entry.value.trip, entry.value.course, entry.value.contact)
    lastUpdated = entry.fetchedAt
    show(entry.value.dive, at: entry.fetchedAt)
    return true
  }

  /// Puts `dive` on screen with what the queue still holds for it laid over.
  private func show(_ dive: DiveReadWithMixtures, at answered: Date) {
    base = dive
    baseAt = answered
    guard let stores = AccountStores.current(session) else {
      hasPendingEdit = false
      phase = .loaded(dive)
      return
    }
    OutboxHub.hub(for: stores.directory).observe(self)
    let items = stores.outbox.items()
    // A failed edit is the pending screen's to correct or discard; the dive shows without it.
    let updates = items.compactMap { item -> DiveUpdate? in
      guard !item.isFailed, case .updateDive(let target, let update) = item.operation,
        target == .server(dive.uuid)
      else { return nil }
      return update
    }
    hasPendingEdit = !updates.isEmpty
    let shown =
      updates.isEmpty
      ? dive : dive.applying(updates, tables: LookupTables(cache: stores.cache, items: items))
    phase = .loaded(shown ?? dive)
  }

  /// The queue changed: an edit queued, or one landed — the cache then holds the dive with it,
  /// as read back or, until that read lands, as the edit left it.
  func accountStoresChanged() {
    guard let base, base.uuid == diveUUID, case .loaded = phase else { return }
    if let entry = AccountStores.current(session)?.cache.dive(base.uuid), entry.fetchedAt > baseAt {
      let dive = entry.value.dive
      trip = (trip ?? entry.value.trip).flatMap { $0.uuid == dive.tripUuid ? $0 : nil }
      course = (course ?? entry.value.course).flatMap { $0.uuid == dive.courseUuid ? $0 : nil }
      contact = (contact ?? entry.value.contact).flatMap { $0.uuid == dive.contactUuid ? $0 : nil }
      show(dive, at: entry.fetchedAt)
    } else {
      show(base, at: baseAt)
    }
  }
}

extension Optional where Wrapped: Sendable {
  fileprivate func asyncMap<T: Sendable>(_ transform: (Wrapped) async -> T) async -> T? {
    guard let self else { return nil }
    return await transform(self)
  }
}
