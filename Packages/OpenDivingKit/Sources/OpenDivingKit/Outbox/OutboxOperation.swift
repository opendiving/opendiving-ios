import Foundation

/// A write the outbox holds for the server, with the body it sends. A create names the record
/// it makes by the item's ``OutboxItem/creates`` ref; every other write names its target here.
public enum OutboxOperation: Hashable, Sendable {
  case createDive(DiveCreate)
  case updateDive(RecordRef, DiveUpdate)
  case createDiveSite(DiveSiteCreate)
  case createPerson(PersonCreate)
  case createTrip(TripCreate)
  case createCourse(CourseCreate)
  /// A dive centre, among others.
  case createContact(ContactCreate)
  case createGearItem(GearItemCreate)
  case createGearSet(GearSetCreate)
  case updateGearSet(RecordRef, GearSetUpdate)
  case createDiveDraft(DiveDraftWrite)
  /// The draft's whole state, which replaces the server's.
  case updateDiveDraft(RecordRef, DiveDraftWrite)
  case deleteDiveDraft(RecordRef)
  /// Creates the dive and removes the draft in one request.
  case logDive(fromDraft: RecordRef, DiveCreate)

  /// What kind of record the write is about.
  public var kind: OutboxRecordKind {
    switch self {
    case .createDive, .updateDive, .logDive: .dive
    case .createDiveSite: .diveSite
    case .createPerson: .person
    case .createTrip: .trip
    case .createCourse: .course
    case .createContact: .contact
    case .createGearItem: .gearItem
    case .createGearSet, .updateGearSet: .gearSet
    case .createDiveDraft, .updateDiveDraft, .deleteDiveDraft: .diveDraft
    }
  }

  /// Whether the write makes a record, and so carries an `Idempotency-Key` and a local ref.
  public var isCreate: Bool {
    switch self {
    case .createDive, .createDiveSite, .createPerson, .createTrip, .createCourse, .createContact,
      .createGearItem, .createGearSet, .createDiveDraft, .logDive:
      true
    case .updateDive, .updateGearSet, .updateDiveDraft, .deleteDiveDraft: false
    }
  }

  /// The record an update, a delete or a log writes to; nil for a plain create.
  public var target: RecordRef? {
    switch self {
    case .updateDive(let ref, _), .updateGearSet(let ref, _), .updateDiveDraft(let ref, _),
      .deleteDiveDraft(let ref), .logDive(let ref, _):
      ref
    default: nil
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
  case dive, diveSite, person, trip, course, contact, gearItem, gearSet, diveDraft
}

extension OutboxOperation: RewritesLocalRefs {
  /// Rewrites the body and the target alike. A target that is dropped is kept: what a write
  /// is about cannot be released from under it, only the write discarded.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    func retarget(_ ref: RecordRef) -> RecordRef { rewrite(ref) ?? ref }
    switch self {
    case .createDive(var body):
      body.rewriteRefs(rewrite)
      self = .createDive(body)
    case .updateDive(let ref, var body):
      body.rewriteRefs(rewrite)
      self = .updateDive(retarget(ref), body)
    case .createDiveSite(var body):
      body.rewriteRefs(rewrite)
      self = .createDiveSite(body)
    case .createPerson(var body):
      body.rewriteRefs(rewrite)
      self = .createPerson(body)
    case .createTrip(var body):
      body.rewriteRefs(rewrite)
      self = .createTrip(body)
    case .createCourse(var body):
      body.rewriteRefs(rewrite)
      self = .createCourse(body)
    case .createContact(var body):
      body.rewriteRefs(rewrite)
      self = .createContact(body)
    case .createGearItem(var body):
      body.rewriteRefs(rewrite)
      self = .createGearItem(body)
    case .createGearSet(var body):
      body.rewriteRefs(rewrite)
      self = .createGearSet(body)
    case .updateGearSet(let ref, var body):
      body.rewriteRefs(rewrite)
      self = .updateGearSet(retarget(ref), body)
    case .createDiveDraft(var body):
      body.rewriteRefs(rewrite)
      self = .createDiveDraft(body)
    case .updateDiveDraft(let ref, var body):
      body.rewriteRefs(rewrite)
      self = .updateDiveDraft(retarget(ref), body)
    case .deleteDiveDraft(let ref):
      self = .deleteDiveDraft(retarget(ref))
    case .logDive(let ref, var body):
      body.rewriteRefs(rewrite)
      self = .logDive(fromDraft: retarget(ref), body)
    }
  }
}

extension OutboxOperation: Codable {
  private enum Kind: String, Codable {
    case createDive, updateDive, createDiveSite, createPerson, createTrip, createCourse,
      createContact, createGearItem, createGearSet, updateGearSet, createDiveDraft,
      updateDiveDraft, deleteDiveDraft, logDive
  }

  private enum CodingKeys: String, CodingKey {
    case kind, target, body
  }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    func body<T: Decodable>(_ type: T.Type) throws -> T { try c.decode(type, forKey: .body) }
    func target() throws -> RecordRef { try c.decode(RecordRef.self, forKey: .target) }
    switch try c.decode(Kind.self, forKey: .kind) {
    case .createDive: self = .createDive(try body(DiveCreate.self))
    case .updateDive: self = .updateDive(try target(), try body(DiveUpdate.self))
    case .createDiveSite: self = .createDiveSite(try body(DiveSiteCreate.self))
    case .createPerson: self = .createPerson(try body(PersonCreate.self))
    case .createTrip: self = .createTrip(try body(TripCreate.self))
    case .createCourse: self = .createCourse(try body(CourseCreate.self))
    case .createContact: self = .createContact(try body(ContactCreate.self))
    case .createGearItem: self = .createGearItem(try body(GearItemCreate.self))
    case .createGearSet: self = .createGearSet(try body(GearSetCreate.self))
    case .updateGearSet: self = .updateGearSet(try target(), try body(GearSetUpdate.self))
    case .createDiveDraft: self = .createDiveDraft(try body(DiveDraftWrite.self))
    case .updateDiveDraft: self = .updateDiveDraft(try target(), try body(DiveDraftWrite.self))
    case .deleteDiveDraft: self = .deleteDiveDraft(try target())
    case .logDive: self = .logDive(fromDraft: try target(), try body(DiveCreate.self))
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeIfPresent(target, forKey: .target)
    switch self {
    case .createDive(let body):
      try c.encode(Kind.createDive, forKey: .kind)
      try c.encode(body, forKey: .body)
    case .updateDive(_, let body):
      try c.encode(Kind.updateDive, forKey: .kind)
      try c.encode(body, forKey: .body)
    case .createDiveSite(let body):
      try c.encode(Kind.createDiveSite, forKey: .kind)
      try c.encode(body, forKey: .body)
    case .createPerson(let body):
      try c.encode(Kind.createPerson, forKey: .kind)
      try c.encode(body, forKey: .body)
    case .createTrip(let body):
      try c.encode(Kind.createTrip, forKey: .kind)
      try c.encode(body, forKey: .body)
    case .createCourse(let body):
      try c.encode(Kind.createCourse, forKey: .kind)
      try c.encode(body, forKey: .body)
    case .createContact(let body):
      try c.encode(Kind.createContact, forKey: .kind)
      try c.encode(body, forKey: .body)
    case .createGearItem(let body):
      try c.encode(Kind.createGearItem, forKey: .kind)
      try c.encode(body, forKey: .body)
    case .createGearSet(let body):
      try c.encode(Kind.createGearSet, forKey: .kind)
      try c.encode(body, forKey: .body)
    case .updateGearSet(_, let body):
      try c.encode(Kind.updateGearSet, forKey: .kind)
      try c.encode(body, forKey: .body)
    case .createDiveDraft(let body):
      try c.encode(Kind.createDiveDraft, forKey: .kind)
      try c.encode(body, forKey: .body)
    case .updateDiveDraft(_, let body):
      try c.encode(Kind.updateDiveDraft, forKey: .kind)
      try c.encode(body, forKey: .body)
    case .deleteDiveDraft:
      try c.encode(Kind.deleteDiveDraft, forKey: .kind)
    case .logDive(_, let body):
      try c.encode(Kind.logDive, forKey: .kind)
      try c.encode(body, forKey: .body)
    }
  }
}
