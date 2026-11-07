/// The *New Dive Site* dialog's values and rules (`diveSiteFormSchema`). The pin's coordinates
/// are text as typed; the locality is the whole place a search found, or the name looked up for
/// the position.
public struct DiveSiteFormValues: Codable, Hashable, Sendable {
  public var name: String
  /// A box per name; a blank one is a row the diver added and left, dropped on save.
  public var otherNames: [String]
  /// The locality around the site.
  public var location: LocationWrite?
  public var latitude: String
  public var longitude: String
  /// Metres.
  public var depthFrom: Double?
  public var depthTo: Double?
  public var waterType: String?
  /// Whole metres above sea level.
  public var altitude: Int?
  public var entryTypes: [String]
  public var tags: [String]
  /// Never typed: what the record being edited carries, which the form can take off.
  public var externalIds: [ExternalIdWrite]
  public var notes: String
  /// Editing a Commons record: the notes and the tags are the diver's, and everything else here
  /// is shown and neither checked nor written.
  public var isCommons = false

  public init(
    name: String = "", otherNames: [String] = [], location: LocationWrite? = nil,
    latitude: String = "", longitude: String = "", depthFrom: Double? = nil,
    depthTo: Double? = nil, waterType: String? = nil, altitude: Int? = nil,
    entryTypes: [String] = [], tags: [String] = [], externalIds: [ExternalIdWrite] = [],
    notes: String = ""
  ) {
    self.name = name
    self.otherNames = otherNames
    self.location = location
    self.latitude = latitude
    self.longitude = longitude
    self.depthFrom = depthFrom
    self.depthTo = depthTo
    self.waterType = waterType
    self.altitude = altitude
    self.entryTypes = entryTypes
    self.tags = tags
    self.externalIds = externalIds
    self.notes = notes
  }

  /// The form an edit opens on.
  public init(editing site: DiveSiteRead) {
    self.init(
      name: site.name, otherNames: site.otherNames, location: site.location.map(LocationWrite.init),
      latitude: CoordinateEntry.text(site.latitude),
      longitude: CoordinateEntry.text(site.longitude), depthFrom: site.depthFrom,
      depthTo: site.depthTo, waterType: site.waterType, altitude: site.altitude,
      entryTypes: site.entryTypes, tags: site.tags,
      externalIds: site.externalIds.map {
        ExternalIdWrite(registry: $0.registry, identifier: $0.identifier)
      },
      notes: site.notes)
    isCommons = site.isCommons
  }

  /// The form a change to a Commons record opens on: its shared members to correct, with none of
  /// the diver's own words.
  public init(changing site: DiveSiteRead) {
    self.init(editing: site)
    isCommons = false
    notes = ""
    tags = []
  }

  public var issues: [FormIssue] {
    var list = FormIssueList()
    if !isCommons {
      list.add("name", FormText.requiredName(name, "Dive site name", max: 255))
      if let location {
        list.add(
          "location", member: "name", FormText.length(location.name, "Location name", max: 255))
        if location.name.isEmpty {
          list.add("location", member: "name", "Location name is required")
        }
      }
      CoordinateEntry.check(latitude: latitude, longitude: longitude, into: &list)
    }
    list.add("notes", FormText.length(notes, "Notes", max: DiveFormBounds.notesMax))
    if !isCommons {
      if let depthFrom, depthFrom < 0 { list.add("depth_from", "Depth from cannot be negative") }
      if let depthTo, depthTo < 0 { list.add("depth_to", "Depth to cannot be negative") }
      if let altitude, !DiveFormBounds.altitudeRange.contains(altitude) {
        list.add("altitude", DiveFormValues.altitudeRangeMessage)
      }
    }
    if tags.contains(where: { $0.unicodeScalars.count > DiveFormBounds.tagMax }) {
      list.add("tags", "A tag can be at most \(DiveFormBounds.tagMax) characters")
    }
    if !isCommons, let depthFrom, let depthTo, depthFrom > depthTo {
      list.add("depth_to", "Depth to cannot be shallower than depth from")
    }
    return list.issues
  }

  /// `POST /dive-site`'s body: the name and the locality's name trimmed, the coordinates as
  /// numbers, blank other names dropped.
  public func toCreate() throws(FormInvalid) -> DiveSiteCreate {
    if !issues.isEmpty { throw FormInvalid(issues: issues) }
    return written
  }

  private var written: DiveSiteCreate {
    var place = location
    place?.name = location?.name.trimmedOfWhitespace ?? ""
    return DiveSiteCreate(
      name: name.trimmedOfWhitespace, latitude: CoordinateEntry.value(latitude),
      longitude: CoordinateEntry.value(longitude), notes: notes,
      otherNames: otherNames.compactMap(FormText.trimmedOrNil), externalIds: externalIds,
      depthFrom: depthFrom, depthTo: depthTo, waterType: waterType, altitude: altitude,
      entryTypes: entryTypes, location: place, tags: tags)
  }

  /// `PATCH /dive-site/{uuid}`'s body: what differs from the values the form opened on, so an
  /// edit saved offline does not undo what the web changed meanwhile. The position goes as a
  /// pair, which is the one value the API takes it as. On a Commons record it is the notes and
  /// the tags alone, whatever a reopened edit laid over the rest: the API refuses anything else.
  public func diff(from baseline: DiveSiteFormValues) throws(FormInvalid) -> DiveSiteUpdate {
    if !issues.isEmpty { throw FormInvalid(issues: issues) }
    let now = written
    let before = baseline.written
    var update = DiveSiteUpdate()
    if now.notes != before.notes { update.notes = now.notes }
    if now.tags != before.tags { update.tags = now.tags }
    if isCommons { return update }
    if now.name != before.name { update.name = now.name }
    if now.otherNames != before.otherNames { update.otherNames = now.otherNames }
    if now.externalIds != before.externalIds { update.externalIds = now.externalIds }
    if now.entryTypes != before.entryTypes { update.entryTypes = now.entryTypes }
    if now.latitude != before.latitude || now.longitude != before.longitude {
      update.latitude = now.latitude.map(Patch.value) ?? .null
      update.longitude = now.longitude.map(Patch.value) ?? .null
    }
    update.depthFrom = .change(from: before.depthFrom, to: now.depthFrom)
    update.depthTo = .change(from: before.depthTo, to: now.depthTo)
    update.waterType = .change(from: before.waterType, to: now.waterType)
    update.altitude = .change(from: before.altitude, to: now.altitude)
    update.location = .change(from: before.location, to: now.location)
    return update
  }

  /// What a proposed change to a Commons record is held to: a site's rules, and the record keeps
  /// its pin.
  public var changeIssues: [FormIssue] {
    let cleared = !CoordinateEntry.isSet(latitude) && !CoordinateEntry.isSet(longitude)
    return issues
      + (cleared ? [FormIssue(field: "latitude", message: "A Commons site keeps its pin")] : [])
  }

  /// A proposed change's `members`: what differs from the record the form opened on. The position
  /// goes as a pair, and the place as its name alone.
  public func change(from baseline: DiveSiteFormValues) throws(FormInvalid)
    -> DiveSiteMembersChange
  {
    if !changeIssues.isEmpty { throw FormInvalid(issues: changeIssues) }
    let now = written
    let before = baseline.written
    var change = DiveSiteMembersChange()
    if now.name != before.name { change.name = now.name }
    if now.otherNames != before.otherNames { change.otherNames = now.otherNames }
    if now.externalIds != before.externalIds { change.externalIds = now.externalIds }
    if now.entryTypes != before.entryTypes { change.entryTypes = now.entryTypes }
    if now.latitude != before.latitude || now.longitude != before.longitude {
      change.latitude = Patch(now.latitude)
      change.longitude = Patch(now.longitude)
    }
    change.depthFrom = .change(from: before.depthFrom, to: now.depthFrom)
    change.depthTo = .change(from: before.depthTo, to: now.depthTo)
    change.waterType = .change(from: before.waterType, to: now.waterType)
    change.altitude = .change(from: before.altitude, to: now.altitude)
    change.locationName = .change(from: before.location?.name, to: now.location?.name)
    return change
  }

  /// These values with a queued update laid over.
  public func applying(_ update: DiveSiteUpdate) -> DiveSiteFormValues {
    var next = self
    if let name = update.name { next.name = name }
    if let notes = update.notes { next.notes = notes }
    if let otherNames = update.otherNames { next.otherNames = otherNames }
    if let externalIds = update.externalIds { next.externalIds = externalIds }
    if let entryTypes = update.entryTypes { next.entryTypes = entryTypes }
    if let tags = update.tags { next.tags = tags }
    if update.latitude != .absent {
      next.latitude = CoordinateEntry.text(update.latitude.applied(to: nil))
      next.longitude = CoordinateEntry.text(update.longitude.applied(to: nil))
    }
    next.depthFrom = update.depthFrom.applied(to: depthFrom)
    next.depthTo = update.depthTo.applied(to: depthTo)
    next.waterType = update.waterType.applied(to: waterType)
    next.altitude = update.altitude.applied(to: altitude)
    next.location = update.location.applied(to: location)
    return next
  }
}

extension DiveSiteFormValues: RewritesLocalRefs {
  /// A site names no other record.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {}
}
