import Foundation

extension OutboxOperation {
  /// The request that sends it, its body encoded so a local ref throws. Every ref must be the
  /// server's by now. A card image's bytes are not here: the flush sends them from the file the
  /// outbox keeps.
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
    case .deleteDive(let ref): return ("DELETE", try path("dive", ref), nil)
    case .createDiveSite(let body): return ("POST", "dive-site", try APIClient.json(body))
    case .updateDiveSite(let ref, let body):
      return ("PATCH", try path("dive-site", ref), try APIClient.json(body))
    case .deleteDiveSite(let ref): return ("DELETE", try path("dive-site", ref), nil)
    case .saveDiveSite(let site): return ("PUT", try path("dive-site", site.ref, "/saved"), nil)
    case .createPerson(let body): return ("POST", "person", try APIClient.json(body))
    case .updatePerson(let ref, let body):
      return ("PATCH", try path("person", ref), try APIClient.json(body))
    case .deletePerson(let ref): return ("DELETE", try path("person", ref), nil)
    case .createTrip(let body): return ("POST", "trip", try APIClient.json(body))
    case .updateTrip(let ref, let body):
      return ("PATCH", try path("trip", ref), try APIClient.json(body))
    case .deleteTrip(let ref): return ("DELETE", try path("trip", ref), nil)
    case .createCourse(let body): return ("POST", "course", try APIClient.json(body))
    case .updateCourse(let ref, let body):
      return ("PATCH", try path("course", ref), try APIClient.json(body))
    case .deleteCourse(let ref): return ("DELETE", try path("course", ref), nil)
    case .createContact(let body): return ("POST", "contact", try APIClient.json(body))
    case .updateContact(let ref, let body):
      return ("PATCH", try path("contact", ref), try APIClient.json(body))
    case .deleteContact(let ref): return ("DELETE", try path("contact", ref), nil)
    case .createGearItem(let body): return ("POST", "gear-item", try APIClient.json(body))
    case .updateGearItem(let ref, let body):
      return ("PATCH", try path("gear-item", ref), try APIClient.json(body))
    case .deleteGearItem(let ref): return ("DELETE", try path("gear-item", ref), nil)
    case .createGearSet(let body): return ("POST", "gear-set", try APIClient.json(body))
    case .updateGearSet(let ref, let body):
      return ("PATCH", try path("gear-set", ref), try APIClient.json(body))
    case .deleteGearSet(let ref): return ("DELETE", try path("gear-set", ref), nil)
    case .createServiceSchedule(let body):
      return ("POST", "gear-service-schedule", try APIClient.json(body))
    case .updateServiceSchedule(let ref, _, let body):
      return ("PATCH", try path("gear-service-schedule", ref), try APIClient.json(body))
    case .deleteServiceSchedule(let ref, _):
      return ("DELETE", try path("gear-service-schedule", ref), nil)
    case .createServiceRecord(let body):
      return ("POST", "gear-service-record", try APIClient.json(body))
    case .updateServiceRecord(let ref, _, let body):
      return ("PATCH", try path("gear-service-record", ref), try APIClient.json(body))
    case .deleteServiceRecord(let ref, _):
      return ("DELETE", try path("gear-service-record", ref), nil)
    case .createCertification(let body):
      return ("POST", "certification", try APIClient.json(body))
    case .updateCertification(let ref, let body):
      return ("PATCH", try path("certification", ref), try APIClient.json(body))
    case .deleteCertification(let ref): return ("DELETE", try path("certification", ref), nil)
    case .putCertificationFile(let ref, let upload):
      return ("PUT", try path("certification", ref, "/file/\(upload.side.rawValue)"), nil)
    case .deleteCertificationFile(let ref, let side):
      return ("DELETE", try path("certification", ref, "/file/\(side.rawValue)"), nil)
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
    case .createServiceSchedule:
      return .record(try decoder.decode(GearServiceScheduleRead.self, from: data).uuid)
    case .createServiceRecord:
      return .record(try decoder.decode(GearServiceRecordRead.self, from: data).uuid)
    case .createCertification:
      return .record(try decoder.decode(CertificationRead.self, from: data).uuid)
    default:
      return nil
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
    case .updateTrip(_, let body):
      return (body.parts ?? []).compactMap(\.accommodation).map { ($0, .contact) }
        + (body.people ?? []).map { ($0.person, .person) }
    case .createCourse(let body):
      return (body.contact.map { [($0, OutboxRecordKind.contact)] } ?? [])
        + body.people.map { ($0.person, .person) }
    case .updateCourse(_, let body):
      return (patched(body.contact).map { [($0, OutboxRecordKind.contact)] } ?? [])
        + (body.people ?? []).map { ($0.person, .person) }
    case .createGearSet(let body): return body.gearItems.map { ($0, .gearItem) }
    case .updateGearSet(_, let body): return (body.gearItems ?? []).map { ($0, .gearItem) }
    case .createServiceSchedule(let body): return [(body.gearItem, .gearItem)]
    case .createServiceRecord(let body):
      return [(body.gearItem, OutboxRecordKind.gearItem)]
        + [(body.schedule, .serviceSchedule), (body.contact, .contact)].compactMap { ref, kind in
          ref.map { ($0, kind) }
        }
    case .updateServiceRecord(_, _, let body):
      return patched(body.contact).map { [($0, .contact)] } ?? []
    case .createCertification(let body):
      return [
        (body.course, OutboxRecordKind.course), (body.contact, .contact),
        (body.instructor, .person),
      ].compactMap { ref, kind in ref.map { ($0, kind) } }
    case .updateCertification(_, let body):
      return [
        (body.course, OutboxRecordKind.course), (body.contact, .contact),
        (body.instructor, .person),
      ].compactMap { patch, kind in patched(patch).map { ($0, kind) } }
    default:
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
