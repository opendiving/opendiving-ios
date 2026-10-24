import Foundation

/// The pickers of the dive form that list the diver's records.
public enum FormPicker: Hashable, Sendable {
  case course
  case trip
  /// The dive centre.
  case contact
  case diveSites
  case people
  case gear
  /// A tank's cylinder, among the gear.
  case cylinder

  /// What a picked record is called while the phone has no name for it, the web's own.
  var unnamed: String {
    switch self {
    case .course: "Course..."
    case .trip: "Trip..."
    case .contact: "Dive center..."
    case .diveSites: "Dive site..."
    case .people: "Person..."
    case .gear, .cylinder: "Gear item..."
    }
  }
}

/// One row a picker offers or shows picked: a record of the diver's, the server's or one the
/// phone has created and not yet sent, which the row marks as pending.
public struct FormPickerRow: Hashable, Sendable, Identifiable {
  public var id: RecordRef { ref }
  public let ref: RecordRef
  public let title: String
  /// What tells two of one name apart, or a cylinder's capacity.
  public let subtitle: String?

  public init(ref: RecordRef, title: String, subtitle: String? = nil) {
    self.ref = ref
    self.title = title
    self.subtitle = subtitle
  }

  /// Created on the phone and not yet on the server.
  public var isPending: Bool { ref.isLocal }

  init(_ row: some LookupRow) {
    self.init(ref: row.ref, title: row.title, subtitle: row.subtitle)
  }

  init(gear item: GearItemInfo) {
    self.init(
      ref: item.ref, title: DiveDetailText.gearItemLabel(name: item.name, brand: item.brand),
      subtitle: item.volume.map { "\(NumberText.plain($0)) L" })
  }
}

/// A species the marine-life picker offers: one the diver has logged, from the life list the
/// phone keeps, or a match the server's search found, which may still need resolving into the
/// catalogue before a dive can name it.
public struct SpeciesPick: Hashable, Sendable, Identifiable {
  public var id: String { uuid?.uuidString ?? "aphia:\(aphiaID ?? 0)" }
  /// The catalogue's species; nil for a register hit the server resolves on pick.
  public let uuid: UUID?
  public let aphiaID: Int?
  public let title: String
  public let subtitle: String?
  /// What the source's licence asks to be shown beside the row.
  public let attribution: String?

  public init(
    uuid: UUID?, aphiaID: Int?, title: String, subtitle: String? = nil,
    attribution: String? = nil
  ) {
    self.uuid = uuid
    self.aphiaID = aphiaID
    self.title = title
    self.subtitle = subtitle
    self.attribution = attribution
  }

  init(_ entry: SpeciesLifeListEntry) {
    self.init(
      uuid: entry.uuid, aphiaID: nil,
      title: SpeciesNames.displayName(
        scientificName: entry.scientificName, commonName: entry.commonName),
      subtitle: entry.commonName == nil ? SpeciesNames.rankLabel(entry.rank) : entry.scientificName)
  }

  init(_ suggestion: SpeciesSuggestion) {
    self.init(
      uuid: suggestion.uuid, aphiaID: suggestion.aphiaId,
      title: SpeciesNames.displayName(
        scientificName: suggestion.scientificName, commonName: suggestion.commonName),
      subtitle: suggestion.commonName == nil
        ? SpeciesNames.rankLabel(suggestion.rank) : suggestion.scientificName,
      attribution: suggestion.attribution.isEmpty ? nil : suggestion.attribution)
  }
}
