/// A record form a sheet edits and queues: its rules, the write saving it queues, and the
/// values read back out of a queued write the server refused.
public protocol RecordSheetValues: Hashable, Sendable {
  var issues: [FormIssue] { get }
  /// The write *Create* queues.
  func operation() throws(FormInvalid) -> OutboxOperation
  /// The values a queued write carried; nil for a write of another kind.
  init?(reopening operation: OutboxOperation)
}

/// Each record form as a sheet queues it, and reads a refused create back. A body keeps less
/// than the form did — a blank box left out, a website given its scheme — so what reopens is
/// what was sent, which saves to the same body again.
extension DiveSiteFormValues: RecordSheetValues {
  public func operation() throws(FormInvalid) -> OutboxOperation { .createDiveSite(try toCreate()) }

  public init?(reopening operation: OutboxOperation) {
    guard case .createDiveSite(let body) = operation else { return nil }
    self.init(
      name: body.name, otherNames: body.otherNames, location: body.location,
      latitude: CoordinateEntry.text(body.latitude),
      longitude: CoordinateEntry.text(body.longitude),
      depthFrom: body.depthFrom, depthTo: body.depthTo, waterType: body.waterType,
      altitude: body.altitude, entryTypes: body.entryTypes, tags: body.tags,
      externalIds: body.externalIds, notes: body.notes)
  }
}

extension PersonFormValues: RecordSheetValues {
  public func operation() throws(FormInvalid) -> OutboxOperation { .createPerson(try toCreate()) }

  public init?(reopening operation: OutboxOperation) {
    guard case .createPerson(let body) = operation else { return nil }
    self.init(
      name: body.name, username: body.username ?? "", email: body.email ?? "",
      phone: body.phone ?? "", notes: body.notes)
  }
}

extension TripFormValues: RecordSheetValues {
  public func operation() throws(FormInvalid) -> OutboxOperation { .createTrip(try toCreate()) }

  public init?(reopening operation: OutboxOperation) {
    guard case .createTrip(let body) = operation else { return nil }
    let parts = body.parts.map {
      TripPartFormValues(
        location: $0.location, startDate: $0.startDate, endDate: $0.endDate,
        accommodation: $0.accommodation)
    }
    self.init(
      name: body.name, parts: parts.isEmpty ? [TripPartFormValues()] : parts,
      people: body.people, notes: body.notes)
  }
}

extension CourseFormValues: RecordSheetValues {
  public func operation() throws(FormInvalid) -> OutboxOperation { .createCourse(try toCreate()) }

  /// The instructor the body put first among the people goes back in its own field.
  public init?(reopening operation: OutboxOperation) {
    guard case .createCourse(let body) = operation else { return nil }
    var people = body.people
    var instructor: RecordRef?
    if let first = people.first, first.role == "instructor" {
      instructor = first.person
      people.removeFirst()
    }
    self.init(
      name: body.name, agency: body.agency, agencyOther: body.agencyOther ?? "",
      status: body.status ?? FormVocabulary.defaultCourseStatus, startDate: body.startDate,
      endDate: body.endDate, instructor: instructor,
      instructorNumber: body.instructorNumber ?? "", contact: body.contact, people: people,
      notes: body.notes)
  }
}

extension ContactFormValues: RecordSheetValues {
  public func operation() throws(FormInvalid) -> OutboxOperation { .createContact(try toCreate()) }

  public init?(reopening operation: OutboxOperation) {
    guard case .createContact(let body) = operation else { return nil }
    let address = body.address
    self.init(
      name: body.name, roles: body.roles, phone: body.phone ?? "", email: body.email ?? "",
      website: body.website ?? "", street: address?.street ?? "", city: address?.city ?? "",
      postcode: address?.postcode ?? "", region: address?.region ?? "",
      country: address?.country ?? "", latitude: CoordinateEntry.text(body.latitude),
      longitude: CoordinateEntry.text(body.longitude), notes: body.notes)
  }
}

extension GearItemFormValues: RecordSheetValues {
  public func operation() throws(FormInvalid) -> OutboxOperation { .createGearItem(try toCreate()) }

  public init?(reopening operation: OutboxOperation) {
    guard case .createGearItem(let body) = operation else { return nil }
    self.init(
      name: body.name, brand: body.brand ?? "", type: body.type, notes: body.notes,
      rented: body.rented, volume: body.volume, workingPressure: body.workingPressure,
      material: body.material)
  }
}
