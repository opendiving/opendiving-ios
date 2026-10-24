import Foundation

extension OutboxOperation {
  /// The request that sends it, its body encoded so a local ref throws. Every ref must be the
  /// server's by now.
  func request() throws -> (method: String, path: String, body: Data?) {
    func path(_ base: String, _ ref: RecordRef, _ suffix: String = "") throws -> String {
      guard let uuid = ref.serverUUID else {
        throw LocalRefOnTheWire(ref: ref, codingPath: [])
      }
      return "\(base)/\(APIClient.wire(uuid))\(suffix)"
    }
    switch self {
    case .createDive(let body): return ("POST", "dive", try APIClient.json(body))
    case .updateDive(let ref, let body):
      return ("PATCH", try path("dive", ref), try APIClient.json(body))
    case .createDiveSite(let body): return ("POST", "dive-site", try APIClient.json(body))
    case .createPerson(let body): return ("POST", "person", try APIClient.json(body))
    case .createTrip(let body): return ("POST", "trip", try APIClient.json(body))
    case .createCourse(let body): return ("POST", "course", try APIClient.json(body))
    case .createContact(let body): return ("POST", "contact", try APIClient.json(body))
    case .createGearItem(let body): return ("POST", "gear-item", try APIClient.json(body))
    case .createGearSet(let body): return ("POST", "gear-set", try APIClient.json(body))
    case .updateGearSet(let ref, let body):
      return ("PATCH", try path("gear-set", ref), try APIClient.json(body))
    case .createDiveDraft(let body): return ("POST", "dive-draft", try APIClient.json(body))
    case .updateDiveDraft(let ref, let body):
      return ("PATCH", try path("dive-draft", ref), try APIClient.json(body))
    case .deleteDiveDraft(let ref): return ("DELETE", try path("dive-draft", ref), nil)
    case .logDive(let ref, let body):
      return ("POST", try path("dive-draft", ref, "/dive"), try APIClient.json(body))
    }
  }

  /// What a success's body is, read: the dive or the draft where the flush has more to do
  /// with it, else the new record's uuid. Nil for a write whose success carries a message.
  /// Throws when the body is not what this build can read.
  func landed(_ data: Data) throws -> LandedRecord? {
    let decoder = APICoding.decoder()
    switch self {
    case .createDive, .logDive:
      return .dive(try decoder.decode(DiveReadWithMixtures.self, from: data))
    case .createDiveDraft: return .draft(try decoder.decode(DiveDraftRead.self, from: data))
    case .createDiveSite: return .record(try decoder.decode(DiveSiteRead.self, from: data).uuid)
    case .createPerson: return .record(try decoder.decode(PersonRead.self, from: data).uuid)
    case .createTrip: return .record(try decoder.decode(TripRead.self, from: data).uuid)
    case .createCourse: return .record(try decoder.decode(CourseRead.self, from: data).uuid)
    case .createContact: return .record(try decoder.decode(ContactRead.self, from: data).uuid)
    case .createGearItem: return .record(try decoder.decode(GearItemRead.self, from: data).uuid)
    case .createGearSet: return .gearSet(try decoder.decode(GearSetRead.self, from: data))
    case .updateDive, .updateGearSet, .updateDiveDraft, .deleteDiveDraft: return nil
    }
  }

  /// Every record the body names, with its kind, read from the member that names it.
  var namedRecords: [(ref: RecordRef, kind: OutboxRecordKind)] {
    func dive(
      trip: RecordRef?, course: RecordRef?, contact: RecordRef?, sites: [RecordRef]?,
      gear: [RecordRef]?, mixtures: [DiveMixtureWrite]?, people: [PersonReference]?
    ) -> [(RecordRef, OutboxRecordKind)] {
      var named: [(RecordRef, OutboxRecordKind)] = []
      if let trip { named.append((trip, .trip)) }
      if let course { named.append((course, .course)) }
      if let contact { named.append((contact, .contact)) }
      named += (sites ?? []).map { ($0, .diveSite) }
      named += (gear ?? []).map { ($0, .gearItem) }
      named += (mixtures ?? []).compactMap(\.gearItem).map { ($0, .gearItem) }
      named += (people ?? []).map { ($0.person, .person) }
      return named
    }
    func patched(_ patch: Patch<RecordRef>) -> RecordRef? {
      if case .value(let ref) = patch { ref } else { nil }
    }
    switch self {
    case .createDive(let body), .logDive(_, let body):
      return dive(
        trip: body.trip, course: body.course, contact: body.contact, sites: body.diveSites,
        gear: body.gearItems, mixtures: body.mixtures, people: body.people)
    case .updateDive(_, let body):
      return dive(
        trip: patched(body.trip), course: patched(body.course), contact: patched(body.contact),
        sites: body.diveSites, gear: body.gearItems, mixtures: body.mixtures, people: body.people)
    case .createDiveDraft(let body), .updateDiveDraft(_, let body):
      let values = body.values
      return (body.gearSet.map { [($0, OutboxRecordKind.gearSet)] } ?? [])
        + dive(
          trip: values.trip, course: values.course, contact: values.contact,
          sites: values.diveSites, gear: values.gearItems, mixtures: values.mixtures,
          people: values.people)
    case .createTrip(let body):
      return body.parts.compactMap(\.accommodation).map { ($0, .contact) }
        + body.people.map { ($0.person, .person) }
    case .createCourse(let body):
      return (body.contact.map { [($0, OutboxRecordKind.contact)] } ?? [])
        + body.people.map { ($0.person, .person) }
    case .createGearSet(let body): return body.gearItems.map { ($0, .gearItem) }
    case .updateGearSet(_, let body): return (body.gearItems ?? []).map { ($0, .gearItem) }
    case .createDiveSite, .createPerson, .createContact, .createGearItem, .deleteDiveDraft:
      return []
    }
  }
}

/// A success's body, read.
enum LandedRecord {
  case dive(DiveReadWithMixtures)
  case draft(DiveDraftRead)
  case gearSet(GearSetRead)
  case record(UUID)

  var uuid: UUID {
    switch self {
    case .dive(let dive): dive.uuid
    case .draft(let draft): draft.uuid
    case .gearSet(let set): set.uuid
    case .record(let uuid): uuid
    }
  }
}
