/// How long a new API key lasts. A vocabulary rather than a date: the server computes
/// `expires_at`.
public enum APIKeyLifetime: String, Codable, Hashable, Sendable, CaseIterable {
  case oneHour = "1h"
  case oneDay = "1d"
  case sevenDays = "7d"
  case thirtyDays = "30d"
  case ninetyDays = "90d"
  case oneYear = "1y"
  case never
}
