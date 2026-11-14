/// What an API key may do: `scoped` is exactly the permissions it lists; `read` and `write` are
/// the legacy keys' access, the safe methods alone or everything a signed-in browser can do.
public enum APIKeyScope: String, Codable, Hashable, Sendable {
  case read
  case write
  case scoped
}
