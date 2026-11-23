import Foundation

/// `POST /dive-computers/known-dives`'s body: a computer's serial and the dives it lists, asked of
/// the logbook before any is downloaded.
public struct KnownDivesQuery: Codable, Hashable, Sendable {
  /// One listed dive: the uuid it would be imported under, and its start as the computer lists
  /// it, a date and time with an offset where the computer logs one.
  public struct Dive: Codable, Hashable, Sendable {
    public let uuid: UUID
    public let startedAt: String

    public init(uuid: UUID, startedAt: String) {
      self.uuid = uuid
      self.startedAt = startedAt
    }

    private enum CodingKeys: String, CodingKey { case uuid, startedAt }

    public init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      uuid = try container.decode(UUID.self, forKey: .uuid)
      startedAt = try container.decode(String.self, forKey: .startedAt)
    }

    /// The uuid in lowercase, as the server spells it back.
    public func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(uuid.uuidString.lowercased(), forKey: .uuid)
      try container.encode(startedAt, forKey: .startedAt)
    }
  }

  public let serial: String
  public let dives: [Dive]

  public init(serial: String, dives: [Dive]) {
    self.serial = serial
    self.dives = dives
  }

  /// The most dives one question may list: a computer listing more is asked in parts.
  public static let maxDives = 2000
}
