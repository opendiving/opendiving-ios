/// `GET /dive/{uuid}`: the dive, with everything its detail page shows. The dive's own fields
/// read straight through, `detail.startTime`.
@dynamicMemberLookup
public struct DiveReadWithMixtures: Codable, Hashable, Sendable {
  public let dive: DiveRead
  public let mixtures: [DiveMixtureRead]
  public let sightings: [SightingRead]
  public let people: [PersonReference]
  public let tags: [String]
  /// In order; the first is the primary.
  public let recordings: [RecordingRead]
  /// Null when the dive does not record enough to derive it.
  public let gasUse: DiveGasUse?

  public subscript<Value>(dynamicMember keyPath: KeyPath<DiveRead, Value>) -> Value {
    dive[keyPath: keyPath]
  }

  enum CodingKeys: String, CodingKey {
    case mixtures, sightings, people, tags, recordings, gasUse
  }

  public init(from decoder: any Decoder) throws {
    dive = try DiveRead(from: decoder)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    mixtures = try c.decode([DiveMixtureRead].self, forKey: .mixtures)
    sightings = try c.decode([SightingRead].self, forKey: .sightings)
    people = try c.decode([PersonReference].self, forKey: .people)
    tags = try c.decode([String].self, forKey: .tags)
    recordings = try c.decode([RecordingRead].self, forKey: .recordings)
    gasUse = try c.decodeIfPresent(DiveGasUse.self, forKey: .gasUse)
  }

  public func encode(to encoder: any Encoder) throws {
    try dive.encode(to: encoder)
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(mixtures, forKey: .mixtures)
    try c.encode(sightings, forKey: .sightings)
    try c.encode(people, forKey: .people)
    try c.encode(tags, forKey: .tags)
    try c.encode(recordings, forKey: .recordings)
    try c.encodeIfPresent(gasUse, forKey: .gasUse)
  }
}
