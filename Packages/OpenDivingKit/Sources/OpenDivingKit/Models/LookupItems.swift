import Foundation

/// A row of `GET /dive-sites/lookup`, with what a dive form fills from the site.
public struct DiveSiteLookupItem: LookupRow {
  public var ref: RecordRef
  public var name: String
  public var location: LocationRead?
  public var waterType: String?
  public var altitude: Int?
  public var entryTypes: [String]

  enum CodingKeys: String, CodingKey {
    case ref = "uuid"
    case name, location, waterType, altitude, entryTypes
  }

  public init(
    ref: RecordRef, name: String, location: LocationRead? = nil, waterType: String? = nil,
    altitude: Int? = nil, entryTypes: [String] = []
  ) {
    self.ref = ref
    self.name = name
    self.location = location
    self.waterType = waterType
    self.altitude = altitude
    self.entryTypes = entryTypes
  }

  public var title: String { name }
  public var subtitle: String? { location?.name }

  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    ref = rewrite(ref) ?? ref
  }
}

/// A row of `GET /trips/lookup`, with the people a dive form fills from the trip.
public struct TripLookupItem: LookupRow {
  public var ref: RecordRef
  public var name: String
  public var people: [PersonReference]

  enum CodingKeys: String, CodingKey {
    case ref = "uuid"
    case name, people
  }

  public init(ref: RecordRef, name: String, people: [PersonReference] = []) {
    self.ref = ref
    self.name = name
    self.people = people
  }

  public var title: String { name }
  public var subtitle: String? { nil }

  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    ref = rewrite(ref) ?? ref
    people.rewritePeople(rewrite)
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
