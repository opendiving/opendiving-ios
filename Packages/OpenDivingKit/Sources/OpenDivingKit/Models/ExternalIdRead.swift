/// A site's identifier in another registry.
public struct ExternalIdRead: Codable, Hashable, Sendable {
  /// The registry's key, as the API sent it.
  public let registry: String
  public let identifier: String
}
