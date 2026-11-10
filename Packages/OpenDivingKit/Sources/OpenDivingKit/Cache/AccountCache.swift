import Foundation

/// What one account's server answered and the phone has shown, kept under `Cache/` in the
/// account's directory so it shows at once, and offline: the lists' pages, the dives, sites,
/// trips and More's records opened, the species photos and card images drawn, the dive drafts, the pickers'
/// lookups, the highest dive number seen, and the profile's figures, places and picture. Nothing is fetched to fill it. A file this build cannot
/// read is dropped and fetched again.
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
    for certification in pages.items as? [CertificationRead] ?? [] {
      dropCardImages(unnamedBy: certification)
    }
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

  /// Drops a dive the server no longer has: its detail, and its row on every kept list of
  /// dives — the profile's and each record's page.
  func removeDive(_ uuid: UUID) {
    remove(Self.divePath(uuid))
    let folder = root.appendingPathComponent("pages", isDirectory: true)
    let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
    let keys = names.filter { $0.hasSuffix(".json") }.map { String($0.dropLast(5)) }.filter {
      key in
      key == PageCacheKey<DiveListItem>.dives.name
        || PageCacheKey<DiveListItem>.recordDivesPrefixes.contains { key.hasPrefix($0) }
    }
    for key in keys {
      guard var entry = pages(key, of: DiveListItem.self),
        entry.value.items.contains(where: { $0.id == uuid })
      else { continue }
      entry.value.items.removeAll { $0.id == uuid }
      write(entry, "pages/\(key).json")
    }
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
    prune("sites") { [PageCacheKey<DiveListItem>.siteDives($0).name] }
  }

  /// Drops a site the server no longer has, with the dives its panel listed.
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
    prune("trips") { [PageCacheKey<DiveListItem>.tripDives($0).name] }
  }

  /// Drops a trip the server no longer has, with the dives its page listed.
  func removeTrip(_ uuid: UUID) {
    remove(Self.detailPath("trips", uuid))
    remove("pages/\(PageCacheKey<DiveListItem>.tripDives(uuid).name).json")
  }

  func touchTrip(_ uuid: UUID) { touch(Self.detailPath("trips", uuid)) }

  // MARK: - More's records

  /// The record as its page last loaded it, or nil when the phone has not shown it.
  public func record<Record>(_ kind: KeptRecordKind<Record>, _ uuid: UUID) -> Entry<Record>? {
    read(Entry<Record>.self, Self.detailPath(kind.folder, uuid))
  }

  func writeRecord<Record>(_ record: Record, _ kind: KeptRecordKind<Record>, fetchedAt: Date) {
    write(
      Entry(value: record, fetchedAt: fetchedAt), Self.detailPath(kind.folder, kind.uuid(record)))
    prune(kind.folder, pages: kind.lists)
    if let certification = record as? CertificationRead {
      dropCardImages(unnamedBy: certification)
    }
  }

  /// Drops a record the server no longer has, with the lists its page showed, and a card's
  /// images with the card.
  func removeRecord<Record>(_ kind: KeptRecordKind<Record>, _ uuid: UUID) {
    remove(Self.detailPath(kind.folder, uuid))
    for list in kind.lists(uuid) { remove("pages/\(list).json") }
    if kind.folder == KeptRecordKind<CertificationRead>.certification.folder {
      remove(Self.cardImagesPath(uuid))
    }
  }

  func touchRecord<Record>(_ kind: KeptRecordKind<Record>, _ uuid: UUID) {
    touch(Self.detailPath(kind.folder, uuid))
  }

  // MARK: - Card images

  /// One side of a card as last fetched, while the card still names that version of it, or nil.
  /// A version is the file's uuid and its `updated_at` (`certificationFileVersion`): a replaced
  /// side moves its `updated_at`, one deleted and uploaded again has a new uuid.
  public func cardImage(_ certification: UUID, _ file: CertificationFileInfo) -> Data? {
    try? Data(
      contentsOf: self.file("\(Self.cardImagesPath(certification))/\(Self.cardImageName(file))"))
  }

  /// Counts a card's kept sides drawn as drawn, for the bound.
  func touchCardImages(_ certification: UUID) { touch(Self.cardImagesPath(certification)) }

  /// Kept in place of any other version of that side, the sides of the most recently drawn
  /// ``detailLimit`` cards kept.
  func writeCardImage(_ data: Data, _ certification: UUID, _ file: CertificationFileInfo) {
    let folder = Self.cardImagesPath(certification)
    let name = Self.cardImageName(file)
    let url = self.file("\(folder)/\(name)")
    try? FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let side = Self.cardImageSide(file.side)
    for older in keptCardImages(certification) where older.hasPrefix(side) && older != name {
      remove("\(folder)/\(older)")
    }
    guard (try? data.write(to: url, options: .atomic)) != nil else { return }
    touchCardImages(certification)
    prune("card-images")
  }

  /// Drops the kept sides `certification` no longer names: a side removed, or replaced while
  /// the phone was not drawing it.
  private func dropCardImages(unnamedBy certification: CertificationRead) {
    let named = Set(certification.files.map(Self.cardImageName))
    let folder = Self.cardImagesPath(certification.uuid)
    for kept in keptCardImages(certification.uuid) where !named.contains(kept) {
      remove("\(folder)/\(kept)")
    }
  }

  private func keptCardImages(_ certification: UUID) -> [String] {
    let folder = root.appendingPathComponent(Self.cardImagesPath(certification), isDirectory: true)
    return (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
  }

  private static func cardImagesPath(_ certification: UUID) -> String {
    "card-images/\(certification.uuidString.lowercased())"
  }

  private static func cardImageSide(_ side: String) -> String {
    side == CertificationSide.back.rawValue ? "back-" : "front-"
  }

  /// `front-<file uuid>-<updated_at's letters and digits>`, so no version is ever a path.
  private static func cardImageName(_ file: CertificationFileInfo) -> String {
    let updated = (file.updatedAt?.wireValue ?? "").filter {
      $0.isASCII && ($0.isLetter || $0.isNumber)
    }
    return cardImageSide(file.side) + file.uuid.uuidString.lowercased() + "-" + updated
  }

  // MARK: - Species photos

  /// How many species photos are kept; the least recently drawn go first. A life list runs
  /// longer than a detail's two hundred, and a photo is a 500-pixel thumbnail.
  public static let speciesPhotoLimit = 500

  /// The photo whose `photoSha256` is `version`, as last fetched, or nil when it is not kept.
  public func speciesPhoto(version: String) -> Data? {
    guard let path = Self.speciesPhotoPath(version) else { return nil }
    return try? Data(contentsOf: file(path))
  }

  /// Counts a kept photo drawn as drawn, for the bound.
  func touchSpeciesPhoto(version: String) {
    if let path = Self.speciesPhotoPath(version) { touch(path) }
  }

  /// Kept by its digest, which names the bytes whichever species shows them.
  func writeSpeciesPhoto(_ data: Data, version: String) {
    guard let path = Self.speciesPhotoPath(version) else { return }
    let url = file(path)
    try? FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard (try? data.write(to: url, options: .atomic)) != nil else { return }
    prune("species-photos", limit: Self.speciesPhotoLimit)
  }

  /// Nil for anything but a lowercase hex digest, so a version is never a path.
  private static func speciesPhotoPath(_ version: String) -> String? {
    guard !version.isEmpty, version.count <= 128,
      version.allSatisfy({ ("0"..."9").contains($0) || ("a"..."f").contains($0) })
    else { return nil }
    return "species-photos/\(version)"
  }

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

  // MARK: - The site finder's map

  /// `GET /dive-sites/points` as last read.
  public var diveSitePoints: Entry<[DiveSitePoint]>? {
    read(Entry<[DiveSitePoint]>.self, "dive-site-points.json")
  }

  func writeDiveSitePoints(_ points: [DiveSitePoint], fetchedAt: Date = Date()) {
    write(Entry(value: points, fetchedAt: fetchedAt), "dive-site-points.json")
  }

  // MARK: - The profile

  /// `GET /user/dive-stats` as last read.
  public var diveStats: Entry<UserDiveStatsRead>? {
    read(Entry<UserDiveStatsRead>.self, "dive-stats.json")
  }

  func writeDiveStats(_ stats: UserDiveStatsRead, fetchedAt: Date = Date()) {
    write(Entry(value: stats, fetchedAt: fetchedAt), "dive-stats.json")
  }

  /// `GET /user/trip-places` as last read.
  public var tripPlaces: Entry<[LocationRead]>? {
    read(Entry<[LocationRead]>.self, "trip-places.json")
  }

  func writeTripPlaces(_ places: [LocationRead], fetchedAt: Date = Date()) {
    write(Entry(value: places, fetchedAt: fetchedAt), "trip-places.json")
  }

  /// The account's picture as last fetched, and the `avatarSha256` it was fetched as.
  public struct Avatar: Sendable {
    public let version: String
    public let data: Data
  }

  public var avatar: Avatar? {
    guard let version = read(Entry<String>.self, "avatar.json")?.value,
      let data = try? Data(contentsOf: file("avatar"))
    else { return nil }
    return Avatar(version: version, data: data)
  }

  /// The bytes first, so a version is never named over another version's picture.
  func writeAvatar(_ avatar: Avatar) {
    remove("avatar.json")
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    guard (try? avatar.data.write(to: file("avatar"), options: .atomic)) != nil else { return }
    write(Entry(value: avatar.version, fetchedAt: Date()), "avatar.json")
  }

  /// Drops a picture the account no longer has.
  func removeAvatar() {
    remove("avatar.json")
    remove("avatar")
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

  /// Keeps the `limit` most recently opened details in `folder`, and drops the pages a dropped
  /// one's page listed, which `pages` names by its uuid.
  private func prune(
    _ folder: String, limit: Int = Self.detailLimit, pages: ((UUID) -> [String])? = nil
  ) {
    let directory = root.appendingPathComponent(folder, isDirectory: true)
    let manager = FileManager.default
    guard let names = try? manager.contentsOfDirectory(atPath: directory.path),
      names.count > limit
    else { return }
    let dated = names.map { name in
      let url = directory.appendingPathComponent(name, isDirectory: false)
      let date = (try? manager.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
      return (url, date ?? .distantPast)
    }
    for (url, _) in dated.sorted(by: { $0.1 < $1.1 }).prefix(names.count - limit) {
      try? manager.removeItem(at: url)
      if let pages, let uuid = UUID(uuidString: url.deletingPathExtension().lastPathComponent) {
        for page in pages(uuid) { remove("pages/\(page).json") }
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
