/// `POST /trip`'s body, `TripCreate`. A trip has no dates of its own; its parts carry them.
public struct TripCreate: Codable, Hashable, Sendable {
  public var name: String
  public var notes: String
  /// In the diver's order, at most twenty.
  public var parts: [TripPartWrite]
  public var people: [PersonReference]

  public init(
    name: String, notes: String = "", parts: [TripPartWrite] = [], people: [PersonReference] = []
  ) {
    self.name = name
    self.notes = notes
    self.parts = parts
    self.people = people
  }
}

/// One stretch of a trip being written, `TripPartInput`.
public struct TripPartWrite: Codable, Hashable, Sendable {
  public var startDate: CalendarDate?
  public var endDate: CalendarDate?
  public var location: LocationWrite?
  /// The contact the diver stayed at.
  public var accommodation: RecordRef?

  enum CodingKeys: String, CodingKey {
    case startDate, endDate, location
    case accommodation = "accommodationUuid"
  }

  public init(
    startDate: CalendarDate? = nil, endDate: CalendarDate? = nil, location: LocationWrite? = nil,
    accommodation: RecordRef? = nil
  ) {
    self.startDate = startDate
    self.endDate = endDate
    self.location = location
    self.accommodation = accommodation
  }
}

extension TripCreate: RewritesLocalRefs {
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    for index in parts.indices {
      parts[index].accommodation.rewrite(rewrite)
    }
    people.rewritePeople(rewrite)
  }
}
