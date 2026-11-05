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

  /// The form an edit opens on. A trip with no parts opens with none, so saving adds no part the
  /// diver did not.
  public init(editing trip: TripRead) {
    self.init(
      name: trip.name, parts: trip.parts.map(TripPartFormValues.init(read:)), people: trip.people,
      notes: trip.notes)
  }

  /// The parts' places that carry a position, in the diver's order.
  public var mapped: [MapPoint] {
    parts.compactMap { $0.location?.mapPoint }
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
    return written
  }

  private var written: TripCreate {
    TripCreate(
      name: name.trimmedOfWhitespace, notes: notes,
      parts: parts.filter(\.holdsSomething).map(\.write), people: people)
  }

  /// `PATCH /trip/{uuid}`'s body: what differs from the values the form opened on, so an edit
  /// saved offline does not undo what the web changed meanwhile.
  public func diff(from baseline: TripFormValues) throws(FormInvalid) -> TripUpdate {
    if !issues.isEmpty { throw FormInvalid(issues: issues) }
    let now = written
    let before = baseline.written
    var update = TripUpdate()
    if now.name != before.name { update.name = now.name }
    if now.notes != before.notes { update.notes = now.notes }
    if now.parts != before.parts { update.parts = now.parts }
    if now.people != before.people { update.people = now.people }
    return update
  }

  /// These values with a queued update laid over.
  public func applying(_ update: TripUpdate) -> TripFormValues {
    var next = self
    if let name = update.name { next.name = name }
    if let notes = update.notes { next.notes = notes }
    if let parts = update.parts { next.parts = parts.map(TripPartFormValues.init(write:)) }
    if let people = update.people { next.people = people }
    return next
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

  init(read: TripPartRead) {
    self.init(
      location: read.location.map(LocationWrite.init), startDate: read.startDate,
      endDate: read.endDate, accommodation: read.accommodationUuid.map(RecordRef.server))
  }

  init(write: TripPartWrite) {
    self.init(
      location: write.location, startDate: write.startDate, endDate: write.endDate,
      accommodation: write.accommodation)
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
