/// Which of the server's two inactivity windows a session slides by: `extended` is what the
/// app asks for at sign-in, and no browser gets it.
public enum IdleTimeout: String, Codable, Hashable, Sendable {
  case standard
  case extended
}
