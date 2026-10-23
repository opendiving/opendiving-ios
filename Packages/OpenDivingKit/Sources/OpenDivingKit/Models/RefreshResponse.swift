/// `POST /auth/refresh`. The rotated refresh token arrives as a `Set-Cookie` beside it.
struct RefreshResponse: Codable, Hashable, Sendable {
  let accessToken: String
  let tokenType: String
}
