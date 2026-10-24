import Foundation

/// One species seen on a dive being written. A count or an abundance band, never both; neither
/// is seen, not counted.
public struct SightingWrite: Hashable, Sendable {
  /// A catalog species: resolved when it was picked, so never the phone's own.
  public var speciesUuid: UUID
  public var count: Int?
  /// `few`, `many` or `abundant`.
  public var abundance: String?
  public var notes: String

  public init(speciesUuid: UUID, count: Int? = nil, abundance: String? = nil, notes: String = "") {
    self.speciesUuid = speciesUuid
    self.count = count
    self.abundance = abundance
    self.notes = notes
  }
}

extension SightingWrite: Codable {
  enum CodingKeys: String, CodingKey { case speciesUuid, count, abundance, notes }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    speciesUuid = try c.decode(UUID.self, forKey: .speciesUuid)
    count = try c.decodeIfPresent(Int.self, forKey: .count)
    abundance = try c.decodeIfPresent(String.self, forKey: .abundance)
    notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
  }

  /// The uuid in the API's own lowercase, as every other uuid the Kit sends.
  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(speciesUuid.uuidString.lowercased(), forKey: .speciesUuid)
    try c.encodeIfPresent(count, forKey: .count)
    try c.encodeIfPresent(abundance, forKey: .abundance)
    try c.encode(notes, forKey: .notes)
  }
}
