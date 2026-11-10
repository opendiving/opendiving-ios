/// `POST /user/api-keys`' body.
public struct APIKeyCreate: Codable, Hashable, Sendable {
  public var name: String
  public var scope: APIKeyScope
  public var lifetime: APIKeyLifetime

  public init(name: String, scope: APIKeyScope, lifetime: APIKeyLifetime) {
    self.name = name
    self.scope = scope
    self.lifetime = lifetime
  }
}
