import Foundation

/// A write the outbox holds for the server, with the body it sends. A create names the record
/// it makes by the item's ``OutboxItem/creates`` ref; every other write names its target here.
public enum OutboxOperation: Hashable, Sendable {
  case createDive(DiveCreate)
  case updateDive(RecordRef, DiveUpdate)
  case deleteDive(RecordRef)
  case createDiveSite(DiveSiteCreate)
  case updateDiveSite(RecordRef, DiveSiteUpdate)
  case deleteDiveSite(RecordRef)
  /// Puts a Commons record on the diver's list. The row is what the lists show meanwhile.
  case saveDiveSite(DiveSiteLookupItem)
  case createPerson(PersonCreate)
  case updatePerson(RecordRef, PersonUpdate)
  case deletePerson(RecordRef)
  case createTrip(TripCreate)
  case updateTrip(RecordRef, TripUpdate)
  case deleteTrip(RecordRef)
  case createCourse(CourseCreate)
  case updateCourse(RecordRef, CourseUpdate)
  case deleteCourse(RecordRef)
  /// A dive centre, among others.
  case createContact(ContactCreate)
  case updateContact(RecordRef, ContactUpdate)
  case deleteContact(RecordRef)
  case createGearItem(GearItemCreate)
  /// An edit, an archive or an unarchive.
  case updateGearItem(RecordRef, GearItemUpdate)
  case deleteGearItem(RecordRef)
  case createGearSet(GearSetCreate)
  case updateGearSet(RecordRef, GearSetUpdate)
  case deleteGearSet(RecordRef)
  case createServiceSchedule(GearServiceScheduleCreate)
  /// `gearItem` is the item the rule is for, which the request does not name.
  case updateServiceSchedule(RecordRef, gearItem: RecordRef, GearServiceScheduleUpdate)
  case deleteServiceSchedule(RecordRef, gearItem: RecordRef)
  case createServiceRecord(GearServiceRecordCreate)
  /// `gearItem` is the item serviced, which the request does not name.
  case updateServiceRecord(RecordRef, gearItem: RecordRef, GearServiceRecordUpdate)
  case deleteServiceRecord(RecordRef, gearItem: RecordRef)
  case createCertification(CertificationCreate)
  case updateCertification(RecordRef, CertificationUpdate)
  case deleteCertification(RecordRef)
  /// A side's image, whose bytes the outbox keeps beside the item; it replaces what the side
  /// holds.
  case putCertificationFile(RecordRef, CertificationCardUpload)
  case deleteCertificationFile(RecordRef, CertificationSide)
  case createDiveDraft(DiveDraftWrite)
  /// The draft's whole state, which replaces the server's.
  case updateDiveDraft(RecordRef, DiveDraftWrite)
  case deleteDiveDraft(RecordRef)
  /// Creates the dive and removes the draft in one request.
  case logDive(fromDraft: RecordRef, DiveCreate)

  /// What kind of record the write is about.
  public var kind: OutboxRecordKind {
    switch self {
    case .createDive, .updateDive, .deleteDive, .logDive: .dive
    case .createDiveSite, .updateDiveSite, .deleteDiveSite, .saveDiveSite: .diveSite
    case .createPerson, .updatePerson, .deletePerson: .person
    case .createTrip, .updateTrip, .deleteTrip: .trip
    case .createCourse, .updateCourse, .deleteCourse: .course
    case .createContact, .updateContact, .deleteContact: .contact
    case .createGearItem, .updateGearItem, .deleteGearItem: .gearItem
    case .createGearSet, .updateGearSet, .deleteGearSet: .gearSet
    case .createServiceSchedule, .updateServiceSchedule, .deleteServiceSchedule:
      .serviceSchedule
    case .createServiceRecord, .updateServiceRecord, .deleteServiceRecord: .serviceRecord
    case .createCertification, .updateCertification, .deleteCertification,
      .putCertificationFile, .deleteCertificationFile:
      .certification
    case .createDiveDraft, .updateDiveDraft, .deleteDiveDraft: .diveDraft
    }
  }

  /// Whether the write makes a record, and so carries an `Idempotency-Key` and a local ref.
  public var isCreate: Bool {
    switch self {
    case .createDive, .createDiveSite, .createPerson, .createTrip, .createCourse, .createContact,
      .createGearItem, .createGearSet, .createServiceSchedule, .createServiceRecord,
      .createCertification, .createDiveDraft, .logDive:
      true
    default:
      false
    }
  }

  /// Whether landing it changes what a list or a record's page shows. A draft has neither.
  var changesLists: Bool {
    switch self {
    case .createDiveDraft, .updateDiveDraft, .deleteDiveDraft: false
    default: true
    }
  }

  /// Whether landing it changes what a picker offers, beyond a new record's own row.
  var changesLookups: Bool {
    switch self {
    case .updateDiveSite, .deleteDiveSite, .saveDiveSite, .updatePerson, .deletePerson,
      .updateTrip, .deleteTrip, .updateCourse, .deleteCourse, .updateContact, .deleteContact,
      .updateGearItem, .deleteGearItem, .updateGearSet, .deleteGearSet:
      true
    default: false
    }
  }

  /// Whether landing it changes the people the session names everyone by.
  var changesPeople: Bool {
    switch self {
    case .createPerson, .updatePerson, .deletePerson: true
    default: false
    }
  }

  /// The record a delete takes off the server, which its list stops showing from the moment it
  /// is queued. Nil for any other write; a draft has no list.
  var deletedRecord: UUID? { deletedRecordRef?.serverUUID }

  /// The record a delete takes off the server, a local one included.
  var deletedRecordRef: RecordRef? {
    switch self {
    case .deleteDive(let ref), .deleteDiveSite(let ref), .deletePerson(let ref),
      .deleteTrip(let ref), .deleteCourse(let ref), .deleteContact(let ref),
      .deleteGearItem(let ref), .deleteGearSet(let ref), .deleteServiceSchedule(let ref, _),
      .deleteServiceRecord(let ref, _), .deleteCertification(let ref):
      ref
    default: nil
    }
  }

  /// Whether a 404 is what the write asked for: a record already gone, a side with no image.
  var isDoneWhenGone: Bool {
    if case .deleteCertificationFile = self { return true }
    return deletedRecord != nil
  }

  /// The record an update, a delete or a log writes to; nil for a plain create.
  public var target: RecordRef? {
    switch self {
    case .updateDive(let ref, _), .updateDiveSite(let ref, _), .updatePerson(let ref, _),
      .updateTrip(let ref, _), .updateCourse(let ref, _), .updateContact(let ref, _),
      .updateGearItem(let ref, _), .updateGearSet(let ref, _),
      .updateServiceSchedule(let ref, _, _), .updateServiceRecord(let ref, _, _),
      .updateCertification(let ref, _), .putCertificationFile(let ref, _),
      .deleteCertificationFile(let ref, _), .updateDiveDraft(let ref, _), .deleteDive(let ref),
      .deleteDiveSite(let ref), .deletePerson(let ref), .deleteTrip(let ref),
      .deleteCourse(let ref), .deleteContact(let ref), .deleteGearItem(let ref),
      .deleteGearSet(let ref), .deleteServiceSchedule(let ref, _),
      .deleteServiceRecord(let ref, _), .deleteCertification(let ref),
      .deleteDiveDraft(let ref), .logDive(let ref, _):
      ref
    case .saveDiveSite(let site): site.ref
    default: nil
    }
  }

  /// The records the write cannot go on without, its target among them: a discard of the
  /// create of any of them withdraws it.
  var requiredRecords: [RecordRef] {
    switch self {
    case .createServiceSchedule(let body): [body.gearItem]
    case .createServiceRecord(let body): [body.gearItem]
    case .updateServiceSchedule(let ref, let item, _), .deleteServiceSchedule(let ref, let item),
      .updateServiceRecord(let ref, let item, _), .deleteServiceRecord(let ref, let item):
      [ref, item]
    default: target.map { [$0] } ?? []
    }
  }

  /// The dive a create or a log would make, for the number the next one is offered.
  public var diveCreate: DiveCreate? {
    switch self {
    case .createDive(let dive), .logDive(_, let dive): dive
    default: nil
    }
  }

  /// Every record the write names, its target included.
  var references: [RecordRef] {
    var refs: [RecordRef] = []
    var copy = self
    copy.rewriteRefs { ref in
      refs.append(ref)
      return ref
    }
    return refs
  }
}

/// The kinds of record the phone writes, for the pending screen's words.
public enum OutboxRecordKind: String, Codable, Hashable, Sendable {
  case dive, diveSite, person, trip, course, contact, gearItem, gearSet, serviceSchedule,
    serviceRecord, certification, diveDraft
}

extension OutboxOperation: RewritesLocalRefs {
  /// Rewrites the body and the target alike. A target that is dropped is kept: what a write
  /// is about cannot be released from under it, only the write discarded.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    func retarget(_ ref: RecordRef) -> RecordRef { rewrite(ref) ?? ref }
    func body<Body: RewritesLocalRefs>(_ value: Body) -> Body {
      var value = value
      value.rewriteRefs(rewrite)
      return value
    }
    switch self {
    case .createDive(let b): self = .createDive(body(b))
    case .updateDive(let ref, let b): self = .updateDive(retarget(ref), body(b))
    case .deleteDive(let ref): self = .deleteDive(retarget(ref))
    case .createDiveSite(let b): self = .createDiveSite(body(b))
    case .updateDiveSite(let ref, let b): self = .updateDiveSite(retarget(ref), body(b))
    case .deleteDiveSite(let ref): self = .deleteDiveSite(retarget(ref))
    case .saveDiveSite(let site): self = .saveDiveSite(body(site))
    case .createPerson(let b): self = .createPerson(body(b))
    case .updatePerson(let ref, let b): self = .updatePerson(retarget(ref), body(b))
    case .deletePerson(let ref): self = .deletePerson(retarget(ref))
    case .createTrip(let b): self = .createTrip(body(b))
    case .updateTrip(let ref, let b): self = .updateTrip(retarget(ref), body(b))
    case .deleteTrip(let ref): self = .deleteTrip(retarget(ref))
    case .createCourse(let b): self = .createCourse(body(b))
    case .updateCourse(let ref, let b): self = .updateCourse(retarget(ref), body(b))
    case .deleteCourse(let ref): self = .deleteCourse(retarget(ref))
    case .createContact(let b): self = .createContact(body(b))
    case .updateContact(let ref, let b): self = .updateContact(retarget(ref), body(b))
    case .deleteContact(let ref): self = .deleteContact(retarget(ref))
    case .createGearItem(let b): self = .createGearItem(body(b))
    case .updateGearItem(let ref, let b): self = .updateGearItem(retarget(ref), body(b))
    case .deleteGearItem(let ref): self = .deleteGearItem(retarget(ref))
    case .createGearSet(let b): self = .createGearSet(body(b))
    case .updateGearSet(let ref, let b): self = .updateGearSet(retarget(ref), body(b))
    case .deleteGearSet(let ref): self = .deleteGearSet(retarget(ref))
    case .createServiceSchedule(let b): self = .createServiceSchedule(body(b))
    case .updateServiceSchedule(let ref, let item, let b):
      self = .updateServiceSchedule(retarget(ref), gearItem: retarget(item), body(b))
    case .deleteServiceSchedule(let ref, let item):
      self = .deleteServiceSchedule(retarget(ref), gearItem: retarget(item))
    case .createServiceRecord(let b): self = .createServiceRecord(body(b))
    case .updateServiceRecord(let ref, let item, let b):
      self = .updateServiceRecord(retarget(ref), gearItem: retarget(item), body(b))
    case .deleteServiceRecord(let ref, let item):
      self = .deleteServiceRecord(retarget(ref), gearItem: retarget(item))
    case .createCertification(let b): self = .createCertification(body(b))
    case .updateCertification(let ref, let b): self = .updateCertification(retarget(ref), body(b))
    case .deleteCertification(let ref): self = .deleteCertification(retarget(ref))
    case .putCertificationFile(let ref, let upload):
      self = .putCertificationFile(retarget(ref), upload)
    case .deleteCertificationFile(let ref, let side):
      self = .deleteCertificationFile(retarget(ref), side)
    case .createDiveDraft(let b): self = .createDiveDraft(body(b))
    case .updateDiveDraft(let ref, let b): self = .updateDiveDraft(retarget(ref), body(b))
    case .deleteDiveDraft(let ref): self = .deleteDiveDraft(retarget(ref))
    case .logDive(let ref, let b): self = .logDive(fromDraft: retarget(ref), body(b))
    }
  }
}

extension OutboxOperation: Codable {
  private enum Kind: String, Codable {
    case createDive, updateDive, createDiveSite, createPerson, createTrip, createCourse,
      createContact, createGearItem, createGearSet, updateGearSet, createDiveDraft,
      updateDiveDraft, deleteDiveDraft, logDive, deleteDive, updateDiveSite, deleteDiveSite,
      updateTrip, deleteTrip, saveDiveSite, updatePerson, deletePerson, updateCourse,
      deleteCourse, updateContact, deleteContact, updateGearItem, deleteGearItem, deleteGearSet,
      createServiceSchedule, updateServiceSchedule, deleteServiceSchedule, createServiceRecord,
      updateServiceRecord, deleteServiceRecord, createCertification, updateCertification,
      deleteCertification, putCertificationFile, deleteCertificationFile
  }

  private enum CodingKeys: String, CodingKey {
    case kind, target, gearItem, body
  }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    func body<T: Decodable>(_ type: T.Type) throws -> T { try c.decode(type, forKey: .body) }
    func target() throws -> RecordRef { try c.decode(RecordRef.self, forKey: .target) }
    func gearItem() throws -> RecordRef { try c.decode(RecordRef.self, forKey: .gearItem) }
    switch try c.decode(Kind.self, forKey: .kind) {
    case .createDive: self = .createDive(try body(DiveCreate.self))
    case .updateDive: self = .updateDive(try target(), try body(DiveUpdate.self))
    case .deleteDive: self = .deleteDive(try target())
    case .createDiveSite: self = .createDiveSite(try body(DiveSiteCreate.self))
    case .updateDiveSite:
      self = .updateDiveSite(try target(), try body(DiveSiteUpdate.self))
    case .deleteDiveSite: self = .deleteDiveSite(try target())
    case .saveDiveSite: self = .saveDiveSite(try body(DiveSiteLookupItem.self))
    case .createPerson: self = .createPerson(try body(PersonCreate.self))
    case .updatePerson: self = .updatePerson(try target(), try body(PersonUpdate.self))
    case .deletePerson: self = .deletePerson(try target())
    case .createTrip: self = .createTrip(try body(TripCreate.self))
    case .updateTrip: self = .updateTrip(try target(), try body(TripUpdate.self))
    case .deleteTrip: self = .deleteTrip(try target())
    case .createCourse: self = .createCourse(try body(CourseCreate.self))
    case .updateCourse: self = .updateCourse(try target(), try body(CourseUpdate.self))
    case .deleteCourse: self = .deleteCourse(try target())
    case .createContact: self = .createContact(try body(ContactCreate.self))
    case .updateContact: self = .updateContact(try target(), try body(ContactUpdate.self))
    case .deleteContact: self = .deleteContact(try target())
    case .createGearItem: self = .createGearItem(try body(GearItemCreate.self))
    case .updateGearItem: self = .updateGearItem(try target(), try body(GearItemUpdate.self))
    case .deleteGearItem: self = .deleteGearItem(try target())
    case .createGearSet: self = .createGearSet(try body(GearSetCreate.self))
    case .updateGearSet: self = .updateGearSet(try target(), try body(GearSetUpdate.self))
    case .deleteGearSet: self = .deleteGearSet(try target())
    case .createServiceSchedule:
      self = .createServiceSchedule(try body(GearServiceScheduleCreate.self))
    case .updateServiceSchedule:
      self = .updateServiceSchedule(
        try target(), gearItem: try gearItem(), try body(GearServiceScheduleUpdate.self))
    case .deleteServiceSchedule:
      self = .deleteServiceSchedule(try target(), gearItem: try gearItem())
    case .createServiceRecord:
      self = .createServiceRecord(try body(GearServiceRecordCreate.self))
    case .updateServiceRecord:
      self = .updateServiceRecord(
        try target(), gearItem: try gearItem(), try body(GearServiceRecordUpdate.self))
    case .deleteServiceRecord:
      self = .deleteServiceRecord(try target(), gearItem: try gearItem())
    case .createCertification:
      self = .createCertification(try body(CertificationCreate.self))
    case .updateCertification:
      self = .updateCertification(try target(), try body(CertificationUpdate.self))
    case .deleteCertification: self = .deleteCertification(try target())
    case .putCertificationFile:
      self = .putCertificationFile(try target(), try body(CertificationCardUpload.self))
    case .deleteCertificationFile:
      self = .deleteCertificationFile(try target(), try body(CertificationSide.self))
    case .createDiveDraft: self = .createDiveDraft(try body(DiveDraftWrite.self))
    case .updateDiveDraft: self = .updateDiveDraft(try target(), try body(DiveDraftWrite.self))
    case .deleteDiveDraft: self = .deleteDiveDraft(try target())
    case .logDive: self = .logDive(fromDraft: try target(), try body(DiveCreate.self))
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeIfPresent(target, forKey: .target)
    func write(_ kind: Kind) throws {
      try c.encode(kind, forKey: .kind)
    }
    func write<Body: Encodable>(_ kind: Kind, _ body: Body) throws {
      try c.encode(kind, forKey: .kind)
      try c.encode(body, forKey: .body)
    }
    switch self {
    case .createDive(let b): try write(.createDive, b)
    case .updateDive(_, let b): try write(.updateDive, b)
    case .deleteDive: try write(.deleteDive)
    case .createDiveSite(let b): try write(.createDiveSite, b)
    case .updateDiveSite(_, let b): try write(.updateDiveSite, b)
    case .deleteDiveSite: try write(.deleteDiveSite)
    case .saveDiveSite(let site): try write(.saveDiveSite, site)
    case .createPerson(let b): try write(.createPerson, b)
    case .updatePerson(_, let b): try write(.updatePerson, b)
    case .deletePerson: try write(.deletePerson)
    case .createTrip(let b): try write(.createTrip, b)
    case .updateTrip(_, let b): try write(.updateTrip, b)
    case .deleteTrip: try write(.deleteTrip)
    case .createCourse(let b): try write(.createCourse, b)
    case .updateCourse(_, let b): try write(.updateCourse, b)
    case .deleteCourse: try write(.deleteCourse)
    case .createContact(let b): try write(.createContact, b)
    case .updateContact(_, let b): try write(.updateContact, b)
    case .deleteContact: try write(.deleteContact)
    case .createGearItem(let b): try write(.createGearItem, b)
    case .updateGearItem(_, let b): try write(.updateGearItem, b)
    case .deleteGearItem: try write(.deleteGearItem)
    case .createGearSet(let b): try write(.createGearSet, b)
    case .updateGearSet(_, let b): try write(.updateGearSet, b)
    case .deleteGearSet: try write(.deleteGearSet)
    case .createServiceSchedule(let b): try write(.createServiceSchedule, b)
    case .updateServiceSchedule(_, let item, let b):
      try c.encode(item, forKey: .gearItem)
      try write(.updateServiceSchedule, b)
    case .deleteServiceSchedule(_, let item):
      try c.encode(item, forKey: .gearItem)
      try write(.deleteServiceSchedule)
    case .createServiceRecord(let b): try write(.createServiceRecord, b)
    case .updateServiceRecord(_, let item, let b):
      try c.encode(item, forKey: .gearItem)
      try write(.updateServiceRecord, b)
    case .deleteServiceRecord(_, let item):
      try c.encode(item, forKey: .gearItem)
      try write(.deleteServiceRecord)
    case .createCertification(let b): try write(.createCertification, b)
    case .updateCertification(_, let b): try write(.updateCertification, b)
    case .deleteCertification: try write(.deleteCertification)
    case .putCertificationFile(_, let upload): try write(.putCertificationFile, upload)
    case .deleteCertificationFile(_, let side): try write(.deleteCertificationFile, side)
    case .createDiveDraft(let b): try write(.createDiveDraft, b)
    case .updateDiveDraft(_, let b): try write(.updateDiveDraft, b)
    case .deleteDiveDraft: try write(.deleteDiveDraft)
    case .logDive(_, let b): try write(.logDive, b)
    }
  }
}
