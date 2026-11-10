/// What an API key may do: `read` is the safe methods alone, `write` what a signed-in browser
/// can.
public enum APIKeyScope: String, Codable, Hashable, Sendable, CaseIterable {
  case read
  case write
}
