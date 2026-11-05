import Foundation
import Observation

/// What the pickers read, online or off: every page of the six lookups, the gear sets, the
/// life list and the recent cylinder volumes, as the server last answered them, each table
/// followed by the records of its kind the phone has created and the server has not yet
/// named.
///
/// A refresh writes only once the account has loaded in this process — before then the only
/// account a store could name is the previous one, and the token may be another's — and runs
/// one at a time per account, the cached rows showing meanwhile.
@MainActor
@Observable
public final class LookupsModel: AccountStoresObserver {
  public private(set) var diveSites: [DiveSiteLookupItem] = []
  /// The Commons records a dive or a draft names and the diver has not saved.
  public private(set) var namedSites: [DiveSiteLookupItem] = []
  public private(set) var trips: [TripLookupItem] = []
  /// Dive centres, among other contacts.
  public private(set) var contacts: [ContactLookupItem] = []
  public private(set) var people: [PersonLookupItem] = []
  public private(set) var courses: [CourseLookupItem] = []
  /// Kit in service; archived items are never listed.
  public private(set) var gearItems: [GearItemLookupItem] = []
  public private(set) var gearSets: [GearSetRow] = []
  public private(set) var lifeList: [SpeciesLifeListEntry] = []
  /// Litres, the most recently used first.
  public private(set) var recentVolumes: [Double] = []
  /// When the oldest table shown was fetched; nil with nothing cached.
  public private(set) var fetchedAt: Date?
  public private(set) var isRefreshing = false

  @ObservationIgnored private let session: Session

  public init(session: Session) {
    self.session = session
    reload()
  }

  /// The tank picker's rows: the cylinders among the gear.
  public var cylinders: [GearItemLookupItem] { gearItems.filter { $0.type == "cylinder" } }

  /// The rows whose title or subtitle holds `search`, ignoring case and accents: a picker's
  /// search over what the phone holds.
  public static func matching<Row: LookupRow>(_ rows: [Row], _ search: String) -> [Row] {
    let needle = search.trimmedOfWhitespace
    guard !needle.isEmpty else { return rows }
    let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
    return rows.filter { row in
      row.title.range(of: needle, options: options) != nil
        || row.subtitle?.range(of: needle, options: options) != nil
    }
  }

  /// Reads the tables again from the stores the session names.
  public func reload() {
    guard let stores = AccountStores.current(session) else {
      (diveSites, trips, contacts, people, courses, gearItems) = ([], [], [], [], [], [])
      (gearSets, lifeList, recentVolumes, fetchedAt) = ([], [], [], nil)
      namedSites = []
      return
    }
    OutboxHub.hub(for: stores.directory).observe(self)
    let tables = LookupTables(cache: stores.cache, items: stores.outbox.items())
    diveSites = tables.diveSites
    namedSites = tables.namedSites
    trips = tables.trips
    contacts = tables.contacts
    people = tables.people
    courses = tables.courses
    gearItems = tables.gearItems
    gearSets = tables.gearSets
    lifeList = tables.lifeList
    recentVolumes = tables.recentVolumes
    fetchedAt = tables.fetchedAt
  }

  func accountStoresChanged() { reload() }

  /// Fetches every table, once the account has loaded; a refresh already running is waited
  /// for rather than doubled.
  public func refresh() async {
    isRefreshing = true
    await Self.refresh(session)
    isRefreshing = false
    reload()
  }

  static func refresh(_ session: Session) async {
    guard let stores = AccountStores.current(session), stores.loaded,
      let client = try? session.requireClient()
    else { return }
    let hub = OutboxHub.hub(for: stores.directory)
    if let running = hub.lookupsRefresh {
      await running.value
      return
    }
    // Cleared by the task itself, so whoever waits on the slot never finds a finished one.
    let task = Task { @MainActor in
      await fetchAll(client, session: session, fetchedUnder: stores)
      hub.lookupsRefresh = nil
      hub.changed()
    }
    hub.lookupsRefresh = task
    await task.value
  }

  private static func fetchAll(
    _ client: APIClient, session: Session, fetchedUnder stores: AccountStores
  ) async {
    func store<Row: Codable & Sendable>(
      _ table: LookupTable, _ fetch: @escaping @Sendable () async throws -> [Row]
    ) async {
      guard let rows = try? await fetch() else { return }
      cacheForAnswer(fetchedUnder: stores, session: session)?.writeLookup(rows, table: table)
    }
    await store(.diveSites) {
      try await APIClient.allPages { try await client.lookupDiveSites(page: $0, itemsPerPage: $1) }
    }
    await store(.trips) {
      try await APIClient.allPages { try await client.lookupTrips(page: $0, itemsPerPage: $1) }
    }
    await store(.contacts) {
      try await APIClient.allPages { try await client.lookupContacts(page: $0, itemsPerPage: $1) }
    }
    await store(.people) {
      try await APIClient.allPages { try await client.lookupPeople(page: $0, itemsPerPage: $1) }
    }
    await store(.courses) {
      try await APIClient.allPages { try await client.lookupCourses(page: $0, itemsPerPage: $1) }
    }
    await store(.gearItems) {
      try await APIClient.allPages { try await client.lookupGearItems(page: $0, itemsPerPage: $1) }
    }
    await store(.gearSets) {
      try await APIClient.allPages { try await client.gearSets(page: $0, itemsPerPage: $1) }
        .map(GearSetRow.init)
    }
    await store(.lifeList) {
      try await APIClient.allPages { try await client.speciesLifeList(page: $0, itemsPerPage: $1) }
    }
    await store(.recentVolumes) { try await client.recentVolumes().volumes }
    await nameSites(client, session: session, fetchedUnder: stores)
  }

  /// Keeps a site for the name a dive or a draft shows, when the diver has not saved it.
  static func keep(_ site: DiveSiteLookupItem, session: Session) {
    guard let stores = AccountStores.current(session) else { return }
    stores.cache.upsertLookupRow(site, table: .namedSites)
    OutboxHub.hub(for: stores.directory).changed()
  }

  /// Fetches the sites the queued writes and the drafts name and the tables do not: a Commons
  /// record picked on another device, or before the phone kept what it picks.
  static func nameSites(
    _ client: APIClient, session: Session, fetchedUnder stores: AccountStores
  ) async {
    let items = stores.outbox.items()
    let tables = LookupTables(cache: stores.cache, items: items)
    let known = Set((tables.diveSites + tables.namedSites).map(\.ref))
    let queued = items.flatMap(\.operation.namedRecords).filter { $0.kind == .diveSite }.map(\.ref)
    let drafted = (stores.cache.diveDrafts?.value ?? []).flatMap { $0.values.diveSites ?? [] }
    let unnamed = Set(queued + drafted).subtracting(known).compactMap(\.serverUUID)
    guard !unnamed.isEmpty,
      let rows = try? await client.lookupDiveSites(
        uuids: Array(unnamed.prefix(APIClient.listPageSize)), page: 1
      ).data,
      let cache = cacheForAnswer(fetchedUnder: stores, session: session)
    else { return }
    for row in rows { cache.upsertLookupRow(row, table: .namedSites) }
  }
}

/// The cached tables with the phone's own records after the server's.
struct LookupTables {
  var diveSites: [DiveSiteLookupItem] = []
  var namedSites: [DiveSiteLookupItem] = []
  var trips: [TripLookupItem] = []
  var contacts: [ContactLookupItem] = []
  var people: [PersonLookupItem] = []
  var courses: [CourseLookupItem] = []
  var gearItems: [GearItemLookupItem] = []
  var gearSets: [GearSetRow] = []
  var lifeList: [SpeciesLifeListEntry] = []
  var recentVolumes: [Double] = []
  var fetchedAt: Date?

  init(cache: AccountCache, items: [OutboxItem]) {
    var dates: [Date] = []
    func rows<Row: Codable & Sendable>(_ table: LookupTable, _ type: Row.Type) -> [Row] {
      guard let entry = cache.lookup(table, of: type) else { return [] }
      dates.append(entry.fetchedAt)
      return entry.value
    }
    diveSites = rows(.diveSites, DiveSiteLookupItem.self)
    namedSites = cache.lookup(.namedSites, of: DiveSiteLookupItem.self)?.value ?? []
    trips = rows(.trips, TripLookupItem.self)
    contacts = rows(.contacts, ContactLookupItem.self)
    people = rows(.people, PersonLookupItem.self)
    courses = rows(.courses, CourseLookupItem.self)
    gearItems = rows(.gearItems, GearItemLookupItem.self)
    gearSets = rows(.gearSets, GearSetRow.self)
    lifeList = rows(.lifeList, SpeciesLifeListEntry.self)
    recentVolumes = rows(.recentVolumes, Double.self)
    fetchedAt = dates.min()

    let waiting = items.filter { !$0.isFailed }
    for item in waiting {
      if case .saveDiveSite(let site) = item.operation,
        !diveSites.contains(where: { $0.ref == site.ref })
      {
        diveSites.append(site)
      }
      guard let ref = item.creates else { continue }
      switch item.operation {
      case .createDiveSite(let body): diveSites.append(body.lookupRow(ref))
      case .createTrip(let body): trips.append(body.lookupRow(ref))
      case .createPerson(let body): people.append(body.lookupRow(ref))
      case .createCourse(let body): courses.append(body.lookupRow(ref))
      case .createContact(let body): contacts.append(body.lookupRow(ref))
      case .createGearItem(let body): gearItems.append(body.lookupRow(ref))
      default: break
      }
    }
    let known = knownGear
    for item in waiting {
      switch item.operation {
      case .createGearSet(let body):
        if let ref = item.creates { gearSets.append(body.row(ref, known: known)) }
      case .updateGearSet(let ref, let update):
        if let index = gearSets.firstIndex(where: { $0.ref == ref }) {
          gearSets[index] = gearSets[index].applying(update, known: known)
        }
      default: break
      }
    }
  }

  /// Every gear item the phone can name: the lookup's, and those the sets list.
  var knownGear: [RecordRef: GearItemInfo] {
    var known: [RecordRef: GearItemInfo] = [:]
    for set in gearSets { for item in set.items { known[item.ref] = item } }
    for item in gearItems { known[item.ref] = item.info }
    return known
  }
}
