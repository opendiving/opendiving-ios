import Foundation

/// A row of `GET /dive-sites/lookup`, with what a dive form fills from the site.
public struct DiveSiteLookupItem: LookupRow {
  public var ref: RecordRef
  public var name: String
  public var otherNames: [String]
  public var latitude: Double?
  public var longitude: Double?
  public var location: LocationRead?
  public var externalIds: [ExternalIdRead]
  public var waterType: String?
  public var altitude: Int?
  public var entryTypes: [String]
  public var owner: String
  /// Whether the site is on the diver's list.
  public var saved: Bool
  /// The credit a Commons record's source asks for, as `[label](href)`; nil on the diver's own.
  public var attribution: String?

  enum CodingKeys: String, CodingKey {
    case ref = "uuid"
    case name, otherNames, latitude, longitude, location, externalIds, waterType, altitude
    case entryTypes, owner, saved, attribution
  }

  public init(
    ref: RecordRef, name: String, otherNames: [String] = [], latitude: Double? = nil,
    longitude: Double? = nil, location: LocationRead? = nil, externalIds: [ExternalIdRead] = [],
    waterType: String? = nil, altitude: Int? = nil, entryTypes: [String] = [],
    owner: String = DiveSiteOwner.account, saved: Bool = true, attribution: String? = nil
  ) {
    self.ref = ref
    self.name = name
    self.otherNames = otherNames
    self.latitude = latitude
    self.longitude = longitude
    self.location = location
    self.externalIds = externalIds
    self.waterType = waterType
    self.altitude = altitude
    self.entryTypes = entryTypes
    self.owner = owner
    self.saved = saved
    self.attribution = attribution
  }

  public var title: String { name }
  public var subtitle: String? { location?.name }
  public var isCommons: Bool { owner == DiveSiteOwner.commons }

  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    ref = rewrite(ref) ?? ref
  }
}

/// A row of `GET /trips/lookup`, with the people a dive form fills from the trip and the parts'
/// dates and places, which the site finder opens on.
public struct TripLookupItem: LookupRow {
  public var ref: RecordRef
  public var name: String
  public var people: [PersonReference]
  public var parts: [TripLookupPart]

  enum CodingKeys: String, CodingKey {
    case ref = "uuid"
    case name, people, parts
  }

  public init(
    ref: RecordRef, name: String, people: [PersonReference] = [], parts: [TripLookupPart] = []
  ) {
    self.ref = ref
    self.name = name
    self.people = people
    self.parts = parts
  }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    ref = try c.decode(RecordRef.self, forKey: .ref)
    name = try c.decode(String.self, forKey: .name)
    people = try c.decode([PersonReference].self, forKey: .people)
    // A row the phone kept before the lookup carried parts has none.
    parts = try c.decodeIfPresent([TripLookupPart].self, forKey: .parts) ?? []
  }

  public var title: String { name }
  public var subtitle: String? { nil }

  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    ref = rewrite(ref) ?? ref
    people.rewritePeople(rewrite)
  }
}

/// A trip part as the trip lookup row carries it: when and where.
public struct TripLookupPart: Codable, Hashable, Sendable {
  public let startDate: CalendarDate?
  public let endDate: CalendarDate?
  public let location: LocationRead?

  public init(
    startDate: CalendarDate? = nil, endDate: CalendarDate? = nil, location: LocationRead? = nil
  ) {
    self.startDate = startDate
    self.endDate = endDate
    self.location = location
  }
}

/// A row of `GET /people/lookup`.
public struct PersonLookupItem: LookupRow {
  public var ref: RecordRef
  public var name: String
  /// The linked account's username.
  public var username: String?

  enum CodingKeys: String, CodingKey {
    case ref = "uuid"
    case name, username
  }

  public init(ref: RecordRef, name: String, username: String? = nil) {
    self.ref = ref
    self.name = name
    self.username = username
  }

  public var title: String { name }
  public var subtitle: String? { username }

  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    ref = rewrite(ref) ?? ref
  }
}

/// A row of `GET /courses/lookup`, with the dive centre and the people a dive form fills from
/// the course.
public struct CourseLookupItem: LookupRow {
  public var ref: RecordRef
  public var name: String
  public var contact: RecordRef?
  public var people: [PersonReference]

  enum CodingKeys: String, CodingKey {
    case ref = "uuid"
    case contact = "contactUuid"
    case name, people
  }

  public init(
    ref: RecordRef, name: String, contact: RecordRef? = nil, people: [PersonReference] = []
  ) {
    self.ref = ref
    self.name = name
    self.contact = contact
    self.people = people
  }

  public var title: String { name }
  public var subtitle: String? { nil }

  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    ref = rewrite(ref) ?? ref
    contact.rewrite(rewrite)
    people.rewritePeople(rewrite)
  }
}

/// A row of `GET /contacts/lookup`.
public struct ContactLookupItem: LookupRow {
  public var ref: RecordRef
  public var name: String
  public var address: ContactAddressRead?

  enum CodingKeys: String, CodingKey {
    case ref = "uuid"
    case name, address
  }

  public init(ref: RecordRef, name: String, address: ContactAddressRead? = nil) {
    self.ref = ref
    self.name = name
    self.address = address
  }

  public var title: String { name }
  /// The city and the country, the parts that tell two dive centres of one name apart.
  public var subtitle: String? {
    guard let address else { return nil }
    let parts = [address.city, address.country].compactMap { $0?.trimmedOfWhitespace }
      .filter { !$0.isEmpty }
    return parts.isEmpty ? nil : parts.joined(separator: ", ")
  }

  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    ref = rewrite(ref) ?? ref
  }
}

/// A row of `GET /gear-items/lookup`: kit in service, with a cylinder's facts.
public struct GearItemLookupItem: LookupRow {
  public var ref: RecordRef
  public var name: String
  public var brand: String?
  public var type: String?
  public var rented: Bool
  public var isArchived: Bool
  public var volume: Double?
  public var workingPressure: Double?
  public var material: String?

  enum CodingKeys: String, CodingKey {
    case ref = "uuid"
    case name, brand, type, rented, isArchived, volume, workingPressure, material
  }

  public init(
    ref: RecordRef, name: String, brand: String? = nil, type: String? = nil,
    rented: Bool = false, isArchived: Bool = false, volume: Double? = nil,
    workingPressure: Double? = nil, material: String? = nil
  ) {
    self.ref = ref
    self.name = name
    self.brand = brand
    self.type = type
    self.rented = rented
    self.isArchived = isArchived
    self.volume = volume
    self.workingPressure = workingPressure
    self.material = material
  }

  public var title: String { name }
  public var subtitle: String? {
    brand.map(\.trimmedOfWhitespace).flatMap { $0.isEmpty ? nil : $0 }
  }

  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    ref = rewrite(ref) ?? ref
  }
}
