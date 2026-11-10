/// A record form a sheet edits and queues: its rules, the write saving it queues, and the
/// values read back out of a queued write the server refused.
public protocol RecordSheetValues: Hashable, Sendable {
  var issues: [FormIssue] { get }
  /// The write *Create* queues.
  func operation() throws(FormInvalid) -> OutboxOperation
  /// The values a queued write carried; nil for a write of another kind.
  init?(reopening operation: OutboxOperation)
}

/// A record form that also edits a record the account has.
public protocol RecordEditValues: RecordSheetValues {
  /// The write taking `ref` from `baseline` to these values; nil when they agree.
  func update(of ref: RecordRef, from baseline: Self) throws(FormInvalid) -> OutboxOperation?
  /// These values with `operation` laid over, where it is a queued update of this kind.
  func applying(_ operation: OutboxOperation) -> Self
  /// The write that deletes `ref`.
  static func delete(_ ref: RecordRef) -> OutboxOperation
}

extension TripFormValues: RecordEditValues {
  public func update(of ref: RecordRef, from baseline: TripFormValues) throws(FormInvalid)
    -> OutboxOperation?
  {
    let update = try diff(from: baseline)
    return update.isEmpty ? nil : .updateTrip(ref, update)
  }

  public func applying(_ operation: OutboxOperation) -> TripFormValues {
    if case .updateTrip(_, let update) = operation { applying(update) } else { self }
  }

  public static func delete(_ ref: RecordRef) -> OutboxOperation { .deleteTrip(ref) }
}

extension DiveSiteFormValues: RecordEditValues {
  public func update(of ref: RecordRef, from baseline: DiveSiteFormValues) throws(FormInvalid)
    -> OutboxOperation?
  {
    let update = try diff(from: baseline)
    return update.isEmpty ? nil : .updateDiveSite(ref, update)
  }

  public func applying(_ operation: OutboxOperation) -> DiveSiteFormValues {
    if case .updateDiveSite(_, let update) = operation { applying(update) } else { self }
  }

  public static func delete(_ ref: RecordRef) -> OutboxOperation { .deleteDiveSite(ref) }
}

extension PersonFormValues: RecordEditValues {
  public func update(of ref: RecordRef, from baseline: PersonFormValues) throws(FormInvalid)
    -> OutboxOperation?
  {
    let update = try diff(from: baseline)
    return update.isEmpty ? nil : .updatePerson(ref, update)
  }

  public func applying(_ operation: OutboxOperation) -> PersonFormValues {
    if case .updatePerson(_, let update) = operation { applying(update) } else { self }
  }

  public static func delete(_ ref: RecordRef) -> OutboxOperation { .deletePerson(ref) }
}

extension CourseFormValues: RecordEditValues {
  public func update(of ref: RecordRef, from baseline: CourseFormValues) throws(FormInvalid)
    -> OutboxOperation?
  {
    let update = try diff(from: baseline)
    return update.isEmpty ? nil : .updateCourse(ref, update)
  }

  public func applying(_ operation: OutboxOperation) -> CourseFormValues {
    if case .updateCourse(_, let update) = operation { applying(update) } else { self }
  }

  public static func delete(_ ref: RecordRef) -> OutboxOperation { .deleteCourse(ref) }
}

extension ContactFormValues: RecordEditValues {
  public func update(of ref: RecordRef, from baseline: ContactFormValues) throws(FormInvalid)
    -> OutboxOperation?
  {
    let update = try diff(from: baseline)
    return update.isEmpty ? nil : .updateContact(ref, update)
  }

  public func applying(_ operation: OutboxOperation) -> ContactFormValues {
    if case .updateContact(_, let update) = operation { applying(update) } else { self }
  }

  public static func delete(_ ref: RecordRef) -> OutboxOperation { .deleteContact(ref) }
}

extension GearItemFormValues: RecordEditValues {
  public func update(of ref: RecordRef, from baseline: GearItemFormValues) throws(FormInvalid)
    -> OutboxOperation?
  {
    let update = try diff(from: baseline)
    return update.isEmpty ? nil : .updateGearItem(ref, update)
  }

  public func applying(_ operation: OutboxOperation) -> GearItemFormValues {
    if case .updateGearItem(_, let update) = operation { applying(update) } else { self }
  }

  public static func delete(_ ref: RecordRef) -> OutboxOperation { .deleteGearItem(ref) }
}

extension GearSetFormValues: RecordEditValues {
  public func update(of ref: RecordRef, from baseline: GearSetFormValues) throws(FormInvalid)
    -> OutboxOperation?
  {
    let update = try diff(from: baseline)
    return update.isEmpty ? nil : .updateGearSet(ref, update)
  }

  public func applying(_ operation: OutboxOperation) -> GearSetFormValues {
    if case .updateGearSet(_, let update) = operation { applying(update) } else { self }
  }

  public static func delete(_ ref: RecordRef) -> OutboxOperation { .deleteGearSet(ref) }
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

extension GearSetFormValues: RecordSheetValues {
  public func operation() throws(FormInvalid) -> OutboxOperation { .createGearSet(try toCreate()) }

  public init?(reopening operation: OutboxOperation) {
    guard case .createGearSet(let body) = operation else { return nil }
    self.init(name: body.name, weight: body.weight, items: body.gearItems)
  }
}
