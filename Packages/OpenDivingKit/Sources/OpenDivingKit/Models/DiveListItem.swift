import Foundation

/// One row of `GET /dives`: the dive, plus what a list card draws that the detail has in
/// full. The dive's own fields read straight through, `item.startTime`.
@dynamicMemberLookup
public struct DiveListItem: Codable, Hashable, Sendable, Identifiable {
  public var id: UUID { dive.uuid }

  public let dive: DiveRead
  /// Null when there is no curve to draw.
  public let depthOutline: DepthOutline?
  public let recordingCount: Int
  public let tags: [String]

  public subscript<Value>(dynamicMember keyPath: KeyPath<DiveRead, Value>) -> Value {
    dive[keyPath: keyPath]
  }

  enum CodingKeys: String, CodingKey {
    case depthOutline, recordingCount, tags
  }

  public init(from decoder: any Decoder) throws {
    dive = try DiveRead(from: decoder)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    depthOutline = try c.decodeIfPresent(DepthOutline.self, forKey: .depthOutline)
    recordingCount = try c.decode(Int.self, forKey: .recordingCount)
    tags = try c.decode([String].self, forKey: .tags)
  }

  public func encode(to encoder: any Encoder) throws {
    try dive.encode(to: encoder)
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeIfPresent(depthOutline, forKey: .depthOutline)
    try c.encode(recordingCount, forKey: .recordingCount)
    try c.encode(tags, forKey: .tags)
  }
}
