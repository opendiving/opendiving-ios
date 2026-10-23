/// `GET /config`: what an instance tells an anonymous client about itself. Only the first two
/// members make a server an OpenDiving instance; the rest are optional so that an older
/// instance still validates, and keys this version has never heard of are ignored.
public struct InstanceConfigRead: Codable, Hashable, Sendable {
  /// `open` or `invite`, read as the string the instance sent.
  public let registrationMode: String
  public let projectOperated: Bool
  public let joinLinks: Bool?
  public let mapTiles: Bool?
}
