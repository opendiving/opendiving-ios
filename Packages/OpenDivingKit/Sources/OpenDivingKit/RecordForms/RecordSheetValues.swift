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

/// *Save as Set*: the set's values and where they go — a new set, or an existing one they
/// replace whole.
public struct GearSetSaveValues: RecordSheetValues {
  public var form: GearSetFormValues
  /// The set replaced; nil creates one.
  public var target: RecordRef?

  public init(form: GearSetFormValues, target: RecordRef? = nil) {
    self.form = form
    self.target = target
  }

  public var issues: [FormIssue] { form.issues }

  public func operation() throws(FormInvalid) -> OutboxOperation {
    if let target { return .updateGearSet(target, try form.toUpdate()) }
    return .createGearSet(try form.toCreate())
  }

  public init?(reopening operation: OutboxOperation) {
    switch operation {
    case .createGearSet(let body):
      self.init(
        form: GearSetFormValues(name: body.name, weight: body.weight, items: body.gearItems))
    case .updateGearSet(let target, let body):
      self.init(
        form: GearSetFormValues(
          name: body.name ?? "", weight: body.weight.applied(to: nil),
          items: body.gearItems ?? []),
        target: target)
    default:
      return nil
    }
  }
}
