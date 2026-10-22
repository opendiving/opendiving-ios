/// A server that answered as an OpenDiving instance, and the build it said it runs.
public struct ServerInfo: Hashable, Sendable {
  public let origin: ServerOrigin
  public let config: InstanceConfigRead
  /// Nil when `GET /health` gave no readable answer; the instance is still valid.
  public let health: HealthRead?
}
