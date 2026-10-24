import Foundation

// The pickers: the cached lookups first, searched on the phone, then — online — the server's
// matches; the trip's and the course's people first in the people picker, and the course's
// dive centre first in its own, with no group label, as the web orders them.
extension DiveFormModel {
  /// How many matches one search asks the server for.
  static let searchPageSize = 25

  // MARK: - Rows

  /// What `picker` offers for `text`, from what the phone holds: the server's rows as last
  /// read, then the records the phone has created, less what the form already holds.
  public func rows(_ picker: FormPicker, matching text: String, tank: Int? = nil)
    -> [FormPickerRow]
  {
    let excluded = self.excluded(picker, tank: tank)
    let rows = table(picker).filter { !excluded.contains($0.ref) }
    return Self.matching(pinnedFirst(rows, picker), text)
  }

  /// The server's matches for `text` the phone's rows do not already offer; none offline, for
  /// an empty search, or when the search fails.
  public func searchServer(_ picker: FormPicker, matching text: String, tank: Int? = nil) async
    -> [FormPickerRow]
  {
    let search = text.trimmedOfWhitespace
    guard isOnline, let client = session.client, !search.isEmpty else { return [] }
    let until = values.startTime
    let size = Self.searchPageSize
    let found: [FormPickerRow]
    do {
      switch picker {
      case .course:
        found = try await client.lookupCourses(
          search: search, until: until, page: 1, itemsPerPage: size
        ).data.map(FormPickerRow.init)
      case .trip:
        found = try await client.lookupTrips(
          search: search, until: until, page: 1, itemsPerPage: size
        ).data.map(FormPickerRow.init)
      case .contact:
        found = try await client.lookupContacts(
          search: search, until: until, page: 1, itemsPerPage: size
        ).data.map(FormPickerRow.init)
      case .diveSites:
        found = try await client.lookupDiveSites(
          search: search, until: until, page: 1, itemsPerPage: size
        ).data.map(FormPickerRow.init)
      case .people:
        found = try await client.lookupPeople(
          search: search, until: until, page: 1, itemsPerPage: size
        ).data.map(FormPickerRow.init)
      case .gear, .cylinder:
        let items = try await client.lookupGearItems(
          search: search, until: until, type: picker == .cylinder ? "cylinder" : nil, page: 1,
          itemsPerPage: size
        ).data.map(\.info)
        remember(gear: items)
        found = items.map { FormPickerRow(gear: $0) }
      }
    } catch {
      return []
    }
    remember(found)
    if picker == .people { rememberPeople(found.map(\.ref)) }
    let shown = Set(rows(picker, matching: search, tank: tank).map(\.ref))
    let excluded = self.excluded(picker, tank: tank)
    return found.filter { !shown.contains($0.ref) && !excluded.contains($0.ref) }
  }

  /// What the picker says when it offers nothing for `text`, the web's sentences.
  public func emptySentence(_ picker: FormPicker, matching text: String, tank: Int? = nil)
    -> String
  {
    let all = table(picker)
    let none = text.trimmedOfWhitespace.isEmpty
    switch picker {
    case .course: return all.isEmpty ? "No courses yet." : "No courses match."
    case .trip: return all.isEmpty ? "No trips yet." : "No trips match."
    case .contact: return all.isEmpty ? "No contacts yet." : "No contacts match."
    case .diveSites: return all.isEmpty ? "No dive sites yet." : "No dive sites match."
    case .people:
      return all.isEmpty && none
        ? "No people yet. Type a name and press Enter to add one."
        : "Nobody matches. Press Enter to add a person of that name."
    case .gear: return all.isEmpty ? "No gear yet." : "No gear matches."
    case .cylinder:
      if all.isEmpty { return "No cylinders in your gear yet." }
      let excluded = self.excluded(picker, tank: tank)
      if none, all.allSatisfy({ excluded.contains($0.ref) }) {
        return "Every cylinder in your gear is already on another tank."
      }
      return "No cylinders match."
    }
  }

  /// A picked record as its row shows it: its name where the phone has one, with its pending
  /// mark; the web's placeholder name otherwise.
  public func row(_ ref: RecordRef, _ picker: FormPicker) -> FormPickerRow {
    if let row = table(picker).first(where: { $0.ref == ref }) { return row }
    if let item = knownGear[ref], picker == .gear || picker == .cylinder {
      return FormPickerRow(gear: item)
    }
    if picker == .people, let person = ref.serverUUID.flatMap(session.person) {
      return FormPickerRow(ref: ref, title: person.name, subtitle: person.username)
    }
    return knownRows[ref] ?? FormPickerRow(ref: ref, title: picker.unnamed)
  }

  /// Every row of `picker`'s table, before anything is left out.
  func table(_ picker: FormPicker) -> [FormPickerRow] {
    switch picker {
    case .course: lookups.courses.map(FormPickerRow.init)
    case .trip: lookups.trips.map(FormPickerRow.init)
    case .contact: lookups.contacts.map(FormPickerRow.init)
    case .diveSites: lookups.diveSites.map(FormPickerRow.init)
    case .people: lookups.people.map(FormPickerRow.init)
    case .gear: lookups.gearItems.map { FormPickerRow(gear: $0.info) }
    case .cylinder: lookups.cylinders.map { FormPickerRow(gear: $0.info) }
    }
  }

  /// What a multi-select already holds, or the cylinders linked on the other tanks.
  private func excluded(_ picker: FormPicker, tank: Int?) -> Set<RecordRef> {
    switch picker {
    case .diveSites: Set(values.diveSites)
    case .people: Set(values.people.map(\.person))
    case .gear: Set(values.gearItems)
    case .cylinder:
      Set(
        values.tanks.enumerated().compactMap { index, other in
          index == tank ? nil : other.cylinder
        })
    case .course, .trip, .contact: []
    }
  }

  /// The trip's and the course's people first in the people picker, the course's dive centre
  /// first in its own.
  private func pinnedFirst(_ rows: [FormPickerRow], _ picker: FormPicker) -> [FormPickerRow] {
    let pinned: [RecordRef]
    switch picker {
    case .people: pinned = roster
    case .contact:
      pinned = lookups.courses.first { $0.ref == values.course }?.contact.map { [$0] } ?? []
    default: return rows
    }
    guard !pinned.isEmpty else { return rows }
    let order = Dictionary(pinned.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
    let first = rows.filter { order[$0.ref] != nil }.sorted { order[$0.ref]! < order[$1.ref]! }
    return first + rows.filter { order[$0.ref] == nil }
  }

  /// The people on the dive's trip, then its course's, each once.
  var roster: [RecordRef] {
    let trip = lookups.trips.first { $0.ref == values.trip }?.people ?? []
    let course = lookups.courses.first { $0.ref == values.course }?.people ?? []
    var seen: Set<RecordRef> = []
    return (trip + course).map(\.person).filter { seen.insert($0).inserted }
  }

  static func matching(_ rows: [FormPickerRow], _ text: String) -> [FormPickerRow] {
    let needle = text.trimmedOfWhitespace
    guard !needle.isEmpty else { return rows }
    let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
    return rows.filter { row in
      row.title.range(of: needle, options: options) != nil
        || row.subtitle?.range(of: needle, options: options) != nil
    }
  }

  // MARK: - Picking

  /// A row picked from a search, so the form can name it afterwards.
  public func remember(_ row: FormPickerRow) {
    remember([row])
  }

  public func setCourse(_ ref: RecordRef?) { change { $0.course = ref } }
  public func setTrip(_ ref: RecordRef?) { change { $0.trip = ref } }
  public func setContact(_ ref: RecordRef?) { change { $0.contact = ref } }

  /// Adds a site after the others: the first is the primary.
  public func addSite(_ ref: RecordRef) {
    change { values in if !values.diveSites.contains(ref) { values.diveSites.append(ref) } }
  }

  public func removeSite(_ ref: RecordRef) { change { $0.diveSites.removeAll { $0 == ref } } }

  /// Moves one site up or down the visiting order, which makes another the primary.
  public func moveSite(_ ref: RecordRef, by offset: Int) {
    change { values in Self.move(ref, by: offset, in: &values.diveSites) }
  }

  /// Adds someone the diver was with: a buddy, until the diver says otherwise.
  public func addPerson(_ ref: RecordRef) {
    change { values in
      guard !values.people.contains(where: { $0.person == ref }) else { return }
      values.people.append(PersonReference(person: ref, role: "buddy"))
    }
  }

  public func removePerson(_ ref: RecordRef) { change { $0.people.removeAll { $0.person == ref } } }

  /// The role on this dive; nil is *No role*.
  public func setRole(_ role: String?, of ref: RecordRef) {
    change { values in
      guard let index = values.people.firstIndex(where: { $0.person == ref }) else { return }
      values.people[index].role = role
    }
  }

  /// Return in the people picker: the person of exactly that name where the phone knows one —
  /// already on the dive, listed, or found by a search — else a new person of that name, queued
  /// and on the dive at once, since the server refuses a second person of one name. False when
  /// the name is not one the web would save.
  @discardableResult
  public func addPerson(named name: String) -> Bool {
    let wanted = name.trimmedOfWhitespace.lowercased()
    guard !wanted.isEmpty else { return false }
    if values.people.contains(where: { row($0.person, .people).title.lowercased() == wanted }) {
      return true
    }
    if let known = knownPerson(named: wanted) {
      addPerson(known)
      return true
    }
    guard let body = try? PersonFormValues(name: name).toCreate(),
      let item = try? outbox.queue(.createPerson(body)), let ref = item.creates
    else { return false }
    remember(FormPickerRow(ref: ref, title: body.name))
    addPerson(ref)
    return true
  }

  /// A person of the account by name, case aside: the lookups', the account's people table, or
  /// one a search found.
  private func knownPerson(named wanted: String) -> RecordRef? {
    if let row = table(.people).first(where: { $0.title.lowercased() == wanted }) { return row.ref }
    if let person = session.people.values.first(where: { $0.name.lowercased() == wanted }) {
      return .server(person.uuid)
    }
    return knownRows.values.first {
      $0.title.lowercased() == wanted && peopleFound.contains($0.ref)
    }?
    .ref
  }

  public func addGear(_ ref: RecordRef) {
    change { values in if !values.gearItems.contains(ref) { values.gearItems.append(ref) } }
  }

  public func removeGear(_ ref: RecordRef) { change { $0.gearItems.removeAll { $0 == ref } } }

  /// A tag, as typed, unless the dive has it already in any case.
  public func addTag(_ text: String) {
    let tag = text.trimmedOfWhitespace
    guard !tag.isEmpty else { return }
    change { values in
      guard !values.tags.contains(where: { $0.lowercased() == tag.lowercased() }) else { return }
      values.tags.append(tag)
    }
  }

  public func removeTag(_ tag: String) { change { $0.tags.removeAll { $0 == tag } } }

  static func move<Element: Equatable>(_ element: Element, by offset: Int, in list: inout [Element])
  {
    guard let index = list.firstIndex(of: element) else { return }
    let target = index + offset
    guard list.indices.contains(target) else { return }
    list.swapAt(index, target)
  }

  // MARK: - Marine life

  /// A species on the dive, by the name the phone knows for it.
  public func speciesName(_ uuid: UUID) -> String {
    if let entry = lookups.lifeList.first(where: { $0.uuid == uuid }) {
      return SpeciesNames.displayName(
        scientificName: entry.scientificName, commonName: entry.commonName)
    }
    return knownSpecies[uuid] ?? "Species..."
  }

  /// The species the diver has logged, from the life list the phone keeps, less those on the
  /// dive: what the picker offers with no signal.
  public func speciesRows(matching text: String) -> [SpeciesPick] {
    let picked = Set(values.sightings.map(\.speciesUuid))
    let needle = text.trimmedOfWhitespace
    let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
    return lookups.lifeList.filter { !picked.contains($0.uuid) }.filter { entry in
      needle.isEmpty || entry.scientificName.range(of: needle, options: options) != nil
        || entry.commonName?.range(of: needle, options: options) != nil
    }.map(SpeciesPick.init)
  }

  /// The server's suggestions for `text` — the dive's sites' species first — less those on the
  /// dive; none offline or for an empty search.
  public func searchSpecies(_ text: String) async -> [SpeciesPick] {
    let query = text.trimmedOfWhitespace
    guard isOnline, let client = session.client, !query.isEmpty else { return [] }
    let picked = values.sightings.map(\.speciesUuid)
    guard
      let answer = try? await client.speciesSuggest(
        query: query, diveSiteUUIDs: values.diveSites.compactMap(\.serverUUID), excluding: picked)
    else { return [] }
    return answer.results.map(SpeciesPick.init)
  }

  /// Puts a species on the dive, seen and not counted — resolving a catalogue match into the
  /// species a dive can name first, which needs the server. False when it could not.
  @discardableResult
  public func addSpecies(_ pick: SpeciesPick) async -> Bool {
    var uuid = pick.uuid
    if uuid == nil, let aphiaID = pick.aphiaID, let client = session.client {
      uuid = try? await client.speciesResolve(aphiaID: aphiaID).uuid
    }
    guard let uuid else { return false }
    remember(species: uuid, name: pick.title)
    change { values in
      guard !values.sightings.contains(where: { $0.speciesUuid == uuid }) else { return }
      values.sightings.append(SightingWrite(speciesUuid: uuid))
    }
    return true
  }

  /// One of the quick choices beside a sighting's count — `one`, or a band — chosen, or taken
  /// off when it already was: a row carries one answer.
  public func chooseQuantity(_ key: String, sighting index: Int) {
    change { values in
      guard values.sightings.indices.contains(index) else { return }
      var sighting = values.sightings[index]
      if key == "one" {
        let isOne = sighting.count == 1
        sighting.count = isOne ? nil : 1
        sighting.abundance = nil
      } else {
        let chosen = sighting.abundance == key
        sighting.abundance = chosen ? nil : key
        sighting.count = nil
      }
      values.sightings[index] = sighting
    }
  }

  /// The count box: a whole number from 1 clears the band, an empty box takes the answer off,
  /// and anything else is not taken.
  public func setCount(_ text: String, sighting index: Int) {
    let trimmed = text.trimmedOfWhitespace
    guard trimmed.isEmpty || (trimmed.first != "0" && trimmed.allSatisfy(\.isASCIIDigit)) else {
      return
    }
    change { values in
      guard values.sightings.indices.contains(index) else { return }
      values.sightings[index].count = Int(trimmed)
      values.sightings[index].abundance = nil
    }
  }
}
