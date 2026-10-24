/// The *New Dive Site* dialog's values and rules (`diveSiteFormSchema`). The pin's coordinates
/// are text as typed; the locality is the whole place a search found, or a name typed by hand.
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
  /// Never typed: a catalogue suggestion adds one.
  public var externalIds: [ExternalIdWrite]
  public var notes: String

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

  public var issues: [FormIssue] {
    var list = FormIssueList()
    list.add("name", FormText.requiredName(name, "Dive site name", max: 255))
    if let location {
      list.add(
        "location", member: "name", FormText.length(location.name, "Location name", max: 255))
      if location.name.isEmpty {
        list.add("location", member: "name", "Location name is required")
      }
    }
    CoordinateEntry.check(latitude: latitude, longitude: longitude, into: &list)
    list.add("notes", FormText.length(notes, "Notes", max: DiveFormBounds.notesMax))
    if let depthFrom, depthFrom < 0 { list.add("depth_from", "Depth from cannot be negative") }
    if let depthTo, depthTo < 0 { list.add("depth_to", "Depth to cannot be negative") }
    if let altitude, !DiveFormBounds.altitudeRange.contains(altitude) {
      list.add("altitude", DiveFormValues.altitudeRangeMessage)
    }
    if tags.contains(where: { $0.unicodeScalars.count > DiveFormBounds.tagMax }) {
      list.add("tags", "A tag can be at most \(DiveFormBounds.tagMax) characters")
    }
    if let depthFrom, let depthTo, depthFrom > depthTo {
      list.add("depth_to", "Depth to cannot be shallower than depth from")
    }
    return list.issues
  }

  /// `POST /dive-site`'s body: the name and the locality's name trimmed, the coordinates as
  /// numbers, blank other names dropped.
  public func toCreate() throws(FormInvalid) -> DiveSiteCreate {
    if !issues.isEmpty { throw FormInvalid(issues: issues) }
    var place = location
    place?.name = location?.name.trimmedOfWhitespace ?? ""
    return DiveSiteCreate(
      name: name.trimmedOfWhitespace, latitude: CoordinateEntry.value(latitude),
      longitude: CoordinateEntry.value(longitude), notes: notes,
      otherNames: otherNames.compactMap(FormText.trimmedOrNil), externalIds: externalIds,
      depthFrom: depthFrom, depthTo: depthTo, waterType: waterType, altitude: altitude,
      entryTypes: entryTypes, location: place, tags: tags)
  }
}

extension DiveSiteFormValues: RewritesLocalRefs {
  /// A site names no other record.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {}
}
