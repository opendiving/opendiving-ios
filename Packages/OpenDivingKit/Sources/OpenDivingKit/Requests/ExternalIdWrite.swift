/// A site's entry in a registry outside the logbook — `openstreetmap` and `node/313862678` — as
/// a dive-site suggestion hands it over.
public struct ExternalIdWrite: Codable, Hashable, Sendable {
  public var registry: String
  public var identifier: String

  public init(registry: String, identifier: String) {
    self.registry = registry
    self.identifier = identifier
  }
}
