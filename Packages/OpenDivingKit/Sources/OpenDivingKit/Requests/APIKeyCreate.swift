/// `POST /user/api-keys`' body.
public struct APIKeyCreate: Codable, Hashable, Sendable {
  public var name: String
  public var scope: APIKeyScope
  /// The permissions a `scoped` key grants, and nil for a legacy one.
  public var scopes: [String]?
  public var lifetime: APIKeyLifetime

  public init(name: String, scope: APIKeyScope, scopes: [String]? = nil, lifetime: APIKeyLifetime) {
    self.name = name
    self.scope = scope
    self.scopes = scopes
    self.lifetime = lifetime
  }
}
