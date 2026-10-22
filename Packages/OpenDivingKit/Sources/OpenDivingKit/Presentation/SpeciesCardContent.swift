import Foundation

/// One species, on a dive's *Species spotted* or a site's species card.
public struct SpeciesCardContent: Hashable, Sendable {
  /// The photo's bytes, already fetched through the Kit's client; nil draws the
  /// no-photo backdrop.
  public var photo: Data?
  /// The common name, or the scientific one for a species with none.
  public var commonName: String
  /// The scientific name with its rank label. Not drawn when it equals ``commonName``.
  public var scientificName: String
  public var figures: [Figure]
  /// A line under the names: the diver's note on a sighting.
  public var note: String?

  public init(
    photo: Data? = nil,
    commonName: String,
    scientificName: String,
    figures: [Figure] = [],
    note: String? = nil
  ) {
    self.photo = photo
    self.commonName = commonName
    self.scientificName = scientificName
    self.figures = figures
    self.note = note
  }
}
