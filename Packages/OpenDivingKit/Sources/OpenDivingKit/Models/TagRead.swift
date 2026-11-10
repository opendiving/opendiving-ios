import Foundation

/// One of the diver's tags, as `GET /tags` lists it. Both counts may be zero: a tag stays until
/// it is deleted.
public struct TagRead: Codable, Hashable, Sendable, Identifiable {
  public let uuid: UUID
  public let name: String
  /// The live dives carrying it.
  public let diveCount: Int
  /// The dive sites carrying it.
  public let siteCount: Int

  public var id: UUID { uuid }

  public init(uuid: UUID, name: String, diveCount: Int, siteCount: Int) {
    self.uuid = uuid
    self.name = name
    self.diveCount = diveCount
    self.siteCount = siteCount
  }
}
