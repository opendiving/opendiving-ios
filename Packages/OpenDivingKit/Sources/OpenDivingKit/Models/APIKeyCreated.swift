/// `POST /user/api-keys`' answer, the one response that ever carries a key's secret: the
/// server keeps only a fingerprint of it.
///
/// Decodable and never encodable, so nothing that writes a value out can be handed one, and
/// described without its secret, so no log line or dump of it can hold the key.
public struct APIKeyCreated: Decodable, Hashable, Sendable {
  /// The key as the list shows it.
  public let key: APIKeyRead
  /// The whole key, to be shown once and copied.
  public let secret: String

  public init(key: APIKeyRead, secret: String) {
    self.key = key
    self.secret = secret
  }

  private enum CodingKeys: String, CodingKey {
    case secret
  }

  public init(from decoder: any Decoder) throws {
    key = try APIKeyRead(from: decoder)
    secret = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .secret)
  }
}

extension APIKeyCreated: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
  public var description: String { "APIKeyCreated(key: \(key), secret: <redacted>)" }
  public var debugDescription: String { description }
  public var customMirror: Mirror { Mirror(self, children: ["key": key]) }
}
