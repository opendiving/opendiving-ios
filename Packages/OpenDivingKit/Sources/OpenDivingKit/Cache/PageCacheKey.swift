import Foundation

/// Where a ``PagedList`` keeps the pages it has shown, per account, and what else a page
/// tells the cache.
public struct PageCacheKey<Item: Codable & Sendable>: Sendable {
  public let name: String
  /// The highest known dive number a first page sets, for the dives list alone.
  let highestDiveNumber: (@Sendable ([Item]) -> Int?)?
  /// The record a row shows, for a list a queued delete takes rows out of.
  let record: (@Sendable (Item) -> UUID)?

  /// A list of its own name, which no other list in the app uses.
  public init(_ name: String) {
    self.name = name
    highestDiveNumber = nil
    record = nil
  }

  init(
    _ name: String, highestDiveNumber: (@Sendable ([Item]) -> Int?)? = nil,
    record: @escaping @Sendable (Item) -> UUID
  ) {
    self.name = name
    self.highestDiveNumber = highestDiveNumber
    self.record = record
  }
}

extension PageCacheKey where Item == DiveListItem {
  /// The profile's *Dives*. Its first row is the newest-dated dive, whose number is the highest the
  /// phone knows.
  public static var dives: Self {
    Self("dives", highestDiveNumber: { $0.first?.diveNumber }, record: \.id)
  }
}

extension PageCacheKey where Item == TripRead {
  /// The profile's *Trips*.
  public static var trips: Self { Self("trips", record: \.uuid) }
}

extension PageCacheKey where Item == DiveListItem {
  /// The dives on one site's panel, kept and dropped with the site's own copy.
  static func siteDives(_ site: UUID) -> Self {
    Self(siteDivesPrefix + site.uuidString.lowercased(), record: \.id)
  }

  /// The dives on one trip's page, kept and dropped with the trip's own copy.
  static func tripDives(_ trip: UUID) -> Self {
    Self(tripDivesPrefix + trip.uuidString.lowercased(), record: \.id)
  }

  /// The dives on one gear item's page, kept and dropped with the item's own copy.
  public static func gearItemDives(_ item: UUID) -> Self {
    Self(gearItemDivesPrefix + item.uuidString.lowercased(), record: \.id)
  }

  /// The dives on one course's page, kept and dropped with the course's own copy.
  public static func courseDives(_ course: UUID) -> Self {
    Self(courseDivesPrefix + course.uuidString.lowercased(), record: \.id)
  }

  /// The dives on one person's page, kept and dropped with the person's own copy.
  public static func personDives(_ person: UUID) -> Self {
    Self(personDivesPrefix + person.uuidString.lowercased(), record: \.id)
  }

  /// The dives on one species' page, kept and dropped with the species' own copy.
  public static func speciesDives(_ species: UUID) -> Self {
    Self(speciesDivesPrefix + species.uuidString.lowercased(), record: \.id)
  }

  static var siteDivesPrefix: String { "site-dives-" }
  static var tripDivesPrefix: String { "trip-dives-" }
  static var gearItemDivesPrefix: String { "gear-item-dives-" }
  static var courseDivesPrefix: String { "course-dives-" }
  static var personDivesPrefix: String { "person-dives-" }
  static var speciesDivesPrefix: String { "species-dives-" }

  /// The start of every kept list of a record's dives, which a dive the server no longer has
  /// leaves.
  static var recordDivesPrefixes: [String] {
    [
      siteDivesPrefix, tripDivesPrefix, gearItemDivesPrefix, courseDivesPrefix,
      personDivesPrefix, speciesDivesPrefix,
    ]
  }
}

extension PageCacheKey where Item == GearItemRead {
  /// More's *Gear*, archived items among them.
  public static var gearItems: Self { Self("gear-items", record: \.uuid) }
}

extension PageCacheKey where Item == GearSetRead {
  /// The gear sets under More's *Gear*.
  public static var gearSets: Self { Self("gear-sets", record: \.uuid) }
}

extension PageCacheKey where Item == GearServiceScheduleRead {
  /// The servicing rules on one gear item's page, kept and dropped with the item's own copy.
  public static func gearServiceSchedules(_ item: UUID) -> Self {
    Self("gear-service-schedules-" + item.uuidString.lowercased(), record: \.uuid)
  }
}

extension PageCacheKey where Item == GearServiceRecordRead {
  /// The service history on one gear item's page, kept and dropped with the item's own copy.
  public static func gearServiceRecords(_ item: UUID) -> Self {
    Self("gear-service-records-" + item.uuidString.lowercased(), record: \.uuid)
  }
}

extension PageCacheKey where Item == CourseRead {
  /// More's *Courses*.
  public static var courses: Self { Self("courses", record: \.uuid) }
}

extension PageCacheKey where Item == CertificationRead {
  /// More's *Certifications*: the account's own list, apart from the check-in sheet's copy.
  public static var certifications: Self { Self("certifications", record: \.uuid) }

  /// The certifications on one course's page, kept and dropped with the course's own copy.
  public static func courseCertifications(_ course: UUID) -> Self {
    Self("course-certifications-" + course.uuidString.lowercased(), record: \.uuid)
  }
}

extension PageCacheKey where Item == PersonRead {
  /// More's *People*.
  public static var people: Self { Self("people", record: \.uuid) }
}

extension PageCacheKey where Item == ContactRead {
  /// More's *Contacts*.
  public static var contacts: Self { Self("contacts", record: \.uuid) }
}

extension PageCacheKey where Item == SpeciesLifeListEntry {
  /// More's *Marine Life*, the life list. A species is logged on a dive and never deleted, so
  /// nothing takes a row out.
  public static var lifeList: Self { Self("life-list") }
}

extension PageCacheKey where Item == DiveSiteSearchRow {
  /// The sites map's untyped list, *Your sites*' or the sites nearest the camera. A place names
  /// no record, so no delete takes it out.
  static func siteFinder(yours: Bool) -> Self {
    Self(yours ? "site-finder-yours" : "site-finder-nearby", record: { siteRecord($0) })
  }

  /// More's *Your dive sites*: the finder's search for the account's sites with no view, apart
  /// from the map's *Your sites*, whose kept pages are the sites in view.
  public static var yourDiveSites: Self { Self("your-dive-sites", record: { siteRecord($0) }) }

  private static func siteRecord(_ row: DiveSiteSearchRow) -> UUID {
    guard case .site(let item) = row, let uuid = item.ref.serverUUID else {
      return UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    }
    return uuid
  }
}
