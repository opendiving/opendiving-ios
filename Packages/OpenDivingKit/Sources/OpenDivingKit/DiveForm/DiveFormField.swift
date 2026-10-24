/// A field of the dive form a diver may hide, the web's `DIVE_FORM_FIELDS` key for key and in its
/// order, each with the label and the section the web gives it. The raw value is the key as the
/// account's hidden set stores it, so these are stored data, not labels.
///
/// The one deliberate difference from the web: ``fileImport`` hides the form's *Import* section,
/// which the phone does not have — files reach the server through the app's import screens — so
/// it is never visible here, hidden or not.
public enum DiveFormField: String, CaseIterable, Sendable, Hashable, Codable {
  case fileImport = "file_import"
  case course = "course_uuid"
  case trip = "trip_uuid"
  case contact = "contact_uuid"
  case diveSites = "dive_site_uuids"
  case entryType = "entry_type"
  case boatName = "boat_name"
  case people = "people"
  case type = "type"
  case maxDepth = "max_depth"
  case avgDepth = "avg_depth"
  case bottomTemperature = "bottom_temperature"
  case visibility = "visibility"
  case waterType = "water_type"
  case altitude = "altitude"
  case waves = "waves"
  case current = "current"
  case weather = "weather"
  case airTemperature = "air_temperature"
  case mixtures = "mixtures"
  case gearItems = "gear_item_uuids"
  case weight = "weight"
  case sightings = "sightings"
  case rating = "rating"
  case tags = "tags"
  case notes = "notes"
  case mixtureCylinder = "mixture.gear_item_uuid"
  case mixturePo2Limit = "mixture.po2_limit"
  case mixtureHelium = "mixture.helium"
  case mixtureStartPressure = "mixture.start_pressure"
  case mixtureEndPressure = "mixture.end_pressure"
  case mixtureUsage = "mixture.usage"
  case mixtureRole = "mixture.role"

  /// The field's own label on the form.
  public var label: String {
    switch self {
    case .fileImport: "Upload dive files"
    case .course: "Course"
    case .trip: "Trip"
    case .contact: "Dive center"
    case .diveSites: "Dive site(s)"
    case .entryType: "Entry type"
    case .boatName: "Boat name"
    case .people: "People"
    case .type: "Dive type"
    case .maxDepth: "Maximum depth"
    case .avgDepth: "Average depth"
    case .bottomTemperature: "Bottom temperature"
    case .visibility: "Visibility"
    case .waterType: "Water type"
    case .altitude: "Altitude"
    case .waves: "Waves"
    case .current: "Current"
    case .weather: "Weather"
    case .airTemperature: "Air temperature"
    case .mixtures: "Tanks"
    case .gearItems: "Gear"
    case .weight: "Weight"
    case .sightings: "Species spotted"
    case .rating: "Rating"
    case .tags: "Tags"
    case .notes: "Notes"
    case .mixtureCylinder: "Cylinder"
    case .mixturePo2Limit: "ppO₂ limit"
    case .mixtureHelium: "He"
    case .mixtureStartPressure: "Start pressure"
    case .mixtureEndPressure: "End pressure"
    case .mixtureUsage: "Usage"
    case .mixtureRole: "Role"
    }
  }

  public var group: DiveFormGroup {
    switch self {
    case .fileImport: .importFiles
    case .course: .training
    case .trip, .contact, .diveSites, .entryType, .boatName: .location
    case .people: .people
    case .type, .maxDepth, .avgDepth: .diveInfo
    case .bottomTemperature, .visibility, .waterType, .altitude, .waves, .current, .weather,
      .airTemperature:
      .environment
    case .mixtures, .mixtureCylinder, .mixturePo2Limit, .mixtureHelium, .mixtureStartPressure,
      .mixtureEndPressure, .mixtureUsage, .mixtureRole:
      .tanks
    case .gearItems, .weight: .gear
    case .sightings: .marineLife
    case .rating, .tags, .notes: .notes
    }
  }

  /// A `mixture.` key, which hides that input on every tank rather than a field of the dive.
  public var isMixtureColumn: Bool { rawValue.hasPrefix("mixture.") }

  /// Whether the form holds a value under the key: every key but the *Import* section's.
  public var holdsValue: Bool { self != .fileImport }

  /// An account's stored hidden set as fields, in form order, each once; a key this build does
  /// not know is a newer build's and is passed over.
  public static func canonical(_ keys: some Sequence<String>) -> [DiveFormField] {
    let present = Set(keys)
    return allCases.filter { present.contains($0.rawValue) }
  }

  /// The inputs the form always shows, with their sections, in form order — the web lists
  /// them so a diver looking for *Dive time* finds it rather than a gap.
  public static let alwaysShown: [(label: String, group: DiveFormGroup)] = [
    ("Start time", .diveInfo),
    ("Dive number", .diveInfo),
    ("Dive time", .diveInfo),
    ("Volume", .tanks),
    ("O₂", .tanks),
  ]
}
