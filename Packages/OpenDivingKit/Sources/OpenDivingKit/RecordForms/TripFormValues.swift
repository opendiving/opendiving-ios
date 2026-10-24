/// The *New Trip* dialog's values and rules (`tripFormSchema`): a name, the parts in the diver's
/// order — a trip carries no dates of its own, its parts do — the people, and notes.
public struct TripFormValues: Codable, Hashable, Sendable {
  public static let maxParts = 20

  public var name: String
  public var parts: [TripPartFormValues]
  public var people: [PersonReference]
  public var notes: String

  /// A new trip opens with one empty part to fill in.
  public init(
    name: String = "", parts: [TripPartFormValues] = [TripPartFormValues()],
    people: [PersonReference] = [], notes: String = ""
  ) {
    self.name = name
    self.parts = parts
    self.people = people
    self.notes = notes
  }

  public var issues: [FormIssue] {
    var list = FormIssueList()
    list.add("name", FormText.requiredName(name, "Trip name", max: 255))
    if parts.count > Self.maxParts {
      list.add("parts", "A trip cannot have more than \(Self.maxParts) parts")
    }
    for (index, part) in parts.enumerated() {
      if let location = part.location {
        list.add(
          "parts", index: index, member: "location",
          FormText.length(location.name, "Location name", max: 255))
        if location.name.isEmpty {
          list.add("parts", index: index, member: "location", "Location name is required")
        }
      }
      if let start = part.startDate, let end = part.endDate, end < start {
        list.add(
          "parts", index: index, member: "end_date", "End date must be on or after start date")
      }
    }
    list.add("notes", FormText.length(notes, "Notes", max: DiveFormBounds.notesMax))
    return list.issues
  }

  /// `POST /trip`'s body: the name trimmed, and only the parts that hold something — the one a
  /// new trip opens with, left untouched, records nothing.
  public func toCreate() throws(FormInvalid) -> TripCreate {
    if !issues.isEmpty { throw FormInvalid(issues: issues) }
    return TripCreate(
      name: name.trimmedOfWhitespace, notes: notes,
      parts: parts.filter(\.holdsSomething).map(\.write), people: people)
  }
}

/// One stretch of a trip as the dialog holds it: a place, dates, where the diver slept — any of
/// them, or none.
public struct TripPartFormValues: Codable, Hashable, Sendable {
  public var location: LocationWrite?
  public var startDate: CalendarDate?
  public var endDate: CalendarDate?
  /// A contact, picked like a course.
  public var accommodation: RecordRef?

  public init(
    location: LocationWrite? = nil, startDate: CalendarDate? = nil, endDate: CalendarDate? = nil,
    accommodation: RecordRef? = nil
  ) {
    self.location = location
    self.startDate = startDate
    self.endDate = endDate
    self.accommodation = accommodation
  }

  var holdsSomething: Bool {
    location != nil || startDate != nil || endDate != nil || accommodation != nil
  }

  var write: TripPartWrite {
    TripPartWrite(
      startDate: startDate, endDate: endDate, location: location, accommodation: accommodation)
  }
}

extension TripFormValues: RewritesLocalRefs {
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    for index in parts.indices {
      parts[index].accommodation.rewrite(rewrite)
    }
    people.rewritePeople(rewrite)
  }
}
