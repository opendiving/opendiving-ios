import Foundation

/// What one account's server answered and the phone has shown, kept under `Cache/` in the
/// account's directory so it shows at once, and offline: the lists' pages, the dives, sites and
/// trips opened, the dive drafts, the pickers' lookups and the highest dive number seen. Nothing is fetched to
/// fill it. A file this build cannot read is dropped and fetched again.
public struct AccountCache: Sendable {
  /// A cached value and when the server answered it.
  public struct Entry<Value: Codable & Sendable>: Codable, Sendable {
    public var value: Value
    public var fetchedAt: Date
  }

  /// The pages of one list the phone has shown, in order.
  public struct Pages<Item: Codable & Sendable>: Codable, Sendable {
    public var items: [Item]
    public var hasMore: Bool
    public var nextPage: Int
  }

  /// A dive the phone has opened, with the records its cards named.
  public struct Dive: Codable, Hashable, Sendable {
    public var dive: DiveReadWithMixtures
    public var trip: TripRead?
    public var course: CourseRead?
    public var contact: ContactRead?

    /// Puts `dive` in place, keeping the records its cards named only where it still names
    /// them.
    mutating func replace(_ dive: DiveReadWithMixtures) {
      self.dive = dive
      trip = trip.flatMap { $0.uuid == dive.tripUuid ? $0 : nil }
      course = course.flatMap { $0.uuid == dive.courseUuid ? $0 : nil }
      contact = contact.flatMap { $0.uuid == dive.contactUuid ? $0 : nil }
    }
  }

  /// A dive site the phone has opened, with the species its card showed.
  public struct Site: Codable, Hashable, Sendable {
    public var site: DiveSiteRead
    public var species: [SpeciesLifeListEntry]?
  }

  /// A trip the phone has opened, with the contacts its information card named.
  public struct Trip: Codable, Hashable, Sendable {
    public var trip: TripRead
    public var contacts: [ContactRead]
  }

  /// How many details of each kind are kept; the least recently opened go first.
  public static let detailLimit = 200

  public let account: UUID
  let root: URL

  public init(store: ServerStateStore, origin: ServerOrigin, account: UUID) {
    self.account = account
    root = store.directory(for: origin, account: account)
      .appendingPathComponent("Cache", isDirectory: true)
  }

  // MARK: - Lists

  public func pages<Item: Codable & Sendable>(_ key: String, of type: Item.Type) -> Entry<
    Pages<Item>
  >? {
    read(Entry<Pages<Item>>.self, "pages/\(key).json")
  }

  func writePages<Item: Codable & Sendable>(_ pages: Pages<Item>, key: String) {
    write(Entry(value: pages, fetchedAt: Date()), "pages/\(key).json")
  }

  // MARK: - Dives

  /// The dive as last loaded, or nil when the phone has not shown it.
  public func dive(_ uuid: UUID) -> Entry<Dive>? {
    read(Entry<Dive>.self, Self.divePath(uuid))
  }

  func writeDive(_ dive: Dive, fetchedAt: Date = Date()) {
    write(Entry(value: dive, fetchedAt: fetchedAt), Self.divePath(dive.dive.uuid))
    prune("dives")
  }

  /// Drops a dive the server no longer has: its detail, and its row on the Dives tab's pages.
  func removeDive(_ uuid: UUID) {
    remove(Self.divePath(uuid))
    let key = PageCacheKey<DiveListItem>.dives.name
    guard var entry = pages(key, of: DiveListItem.self),
      entry.value.items.contains(where: { $0.id == uuid })
    else { return }
    entry.value.items.removeAll { $0.id == uuid }
    write(entry, "pages/\(key).json")
  }

  /// Counts a dive opened from the cache as opened, for the bound.
  func touchDive(_ uuid: UUID) {
    touch(Self.divePath(uuid))
  }

  // MARK: - Sites and trips

  /// The site as last loaded, or nil when the phone has not shown it.
  public func site(_ uuid: UUID) -> Entry<Site>? {
    read(Entry<Site>.self, Self.detailPath("sites", uuid))
  }

  func writeSite(_ site: Site, fetchedAt: Date) {
    write(Entry(value: site, fetchedAt: fetchedAt), Self.detailPath("sites", site.site.uuid))
    prune("sites") { PageCacheKey<DiveListItem>.siteDives($0).name }
  }

  /// Drops a site the server no longer has, with the dives its page listed.
  func removeSite(_ uuid: UUID) {
    remove(Self.detailPath("sites", uuid))
    remove("pages/\(PageCacheKey<DiveListItem>.siteDives(uuid).name).json")
  }

  func touchSite(_ uuid: UUID) { touch(Self.detailPath("sites", uuid)) }

  /// The trip as last loaded, or nil when the phone has not shown it.
  public func trip(_ uuid: UUID) -> Entry<Trip>? {
    read(Entry<Trip>.self, Self.detailPath("trips", uuid))
  }

  func writeTrip(_ trip: Trip, fetchedAt: Date) {
    write(Entry(value: trip, fetchedAt: fetchedAt), Self.detailPath("trips", trip.trip.uuid))
    prune("trips") { PageCacheKey<DiveListItem>.tripDives($0).name }
  }

  /// Drops a trip the server no longer has, with the dives its page listed.
  func removeTrip(_ uuid: UUID) {
    remove(Self.detailPath("trips", uuid))
    remove("pages/\(PageCacheKey<DiveListItem>.tripDives(uuid).name).json")
  }

  func touchTrip(_ uuid: UUID) { touch(Self.detailPath("trips", uuid)) }

  /// The number of the newest-dated dive the phone has seen: the first row of the dives page
  /// last loaded, raised by a create that landed with a higher number.
  public var highestDiveNumber: Int? {
    read(Entry<Int>.self, "highest-dive-number.json")?.value
  }

  func setHighestDiveNumber(_ number: Int) {
    write(Entry(value: number, fetchedAt: Date()), "highest-dive-number.json")
  }

  func raiseHighestDiveNumber(to number: Int) {
    guard number > highestDiveNumber ?? Int.min else { return }
    setHighestDiveNumber(number)
  }

  // MARK: - Dive drafts

  /// Every page of `GET /dive-drafts` as last read, the most recently changed first.
  public var diveDrafts: Entry<[DiveDraftRead]>? {
    read(Entry<[DiveDraftRead]>.self, "dive-drafts.json")
  }

  func writeDiveDrafts(_ drafts: [DiveDraftRead], fetchedAt: Date = Date()) {
    write(Entry(value: drafts, fetchedAt: fetchedAt), "dive-drafts.json")
  }

  /// Puts `draft` in place of the copy of the same uuid, or first.
  func replaceDiveDraft(_ draft: DiveDraftRead) {
    var entry = diveDrafts ?? Entry(value: [], fetchedAt: Date())
    if let index = entry.value.firstIndex(where: { $0.uuid == draft.uuid }) {
      entry.value[index] = draft
    } else {
      entry.value.insert(draft, at: 0)
    }
    write(entry, "dive-drafts.json")
  }

  func removeDiveDraft(_ uuid: UUID) {
    guard var entry = diveDrafts, entry.value.contains(where: { $0.uuid == uuid }) else { return }
    entry.value.removeAll { $0.uuid == uuid }
    write(entry, "dive-drafts.json")
  }

  // MARK: - Lookups

  public func lookup<Row: Codable & Sendable>(_ table: LookupTable, of type: Row.Type) -> Entry<
    [Row]
  >? {
    read(Entry<[Row]>.self, "lookups/\(table.rawValue).json")
  }

  func writeLookup<Row: Codable & Sendable>(
    _ rows: [Row], table: LookupTable, fetchedAt: Date = Date()
  ) {
    write(Entry(value: rows, fetchedAt: fetchedAt), "lookups/\(table.rawValue).json")
  }

  /// Adds `row` to its table, or replaces the row of the same ref.
  func upsertLookupRow<Row: LookupRow>(_ row: Row, table: LookupTable) {
    var entry = lookup(table, of: Row.self) ?? Entry(value: [], fetchedAt: Date())
    if let index = entry.value.firstIndex(where: { $0.ref == row.ref }) {
      entry.value[index] = row
    } else {
      entry.value.append(row)
    }
    write(entry, "lookups/\(table.rawValue).json")
  }

  // MARK: - Files

  private func read<Value: Decodable>(_ type: Value.Type, _ path: String) -> Value? {
    let url = file(path)
    guard let data = try? Data(contentsOf: url) else { return nil }
    guard let value = try? APICoding.decoder().decode(type, from: data) else {
      try? FileManager.default.removeItem(at: url)
      return nil
    }
    return value
  }

  /// A cache write that fails leaves the cache as it was; the next answer tries again.
  private func write(_ value: some Encodable, _ path: String) {
    let url = file(path)
    try? FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? APICoding.encoder().encode(value).write(to: url, options: .atomic)
  }

  private func remove(_ path: String) {
    try? FileManager.default.removeItem(at: file(path))
  }

  private func touch(_ path: String) {
    try? FileManager.default.setAttributes(
      [.modificationDate: Date()], ofItemAtPath: file(path).path)
  }

  private func file(_ path: String) -> URL {
    root.appendingPathComponent(path, isDirectory: false)
  }

  private static func divePath(_ uuid: UUID) -> String {
    detailPath("dives", uuid)
  }

  private static func detailPath(_ folder: String, _ uuid: UUID) -> String {
    "\(folder)/\(uuid.uuidString.lowercased()).json"
  }

  /// Keeps the ``detailLimit`` most recently opened details in `folder`, and drops the pages a
  /// dropped one's page listed, which `pages` names by its uuid.
  private func prune(_ folder: String, pages: ((UUID) -> String)? = nil) {
    let directory = root.appendingPathComponent(folder, isDirectory: true)
    let manager = FileManager.default
    guard let names = try? manager.contentsOfDirectory(atPath: directory.path),
      names.count > Self.detailLimit
    else { return }
    let dated = names.map { name in
      let url = directory.appendingPathComponent(name, isDirectory: false)
      let date = (try? manager.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
      return (url, date ?? .distantPast)
    }
    for (url, _) in dated.sorted(by: { $0.1 < $1.1 }).prefix(names.count - Self.detailLimit) {
      try? manager.removeItem(at: url)
      if let pages, let uuid = UUID(uuidString: url.deletingPathExtension().lastPathComponent) {
        remove("pages/\(pages(uuid)).json")
      }
    }
  }
}

/// The pickers' tables the lookups cache keeps.
public enum LookupTable: String, CaseIterable, Sendable {
  case diveSites, trips, contacts, people, courses, gearItems, gearSets, lifeList, recentVolumes
  /// Commons records a dive or a draft names without the diver having saved them, which no
  /// refresh of `diveSites` brings. Never offered by a picker, only read to name them.
  case namedSites
}
