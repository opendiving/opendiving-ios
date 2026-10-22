/// The one server the app is pointed at, kept across launches so that a relaunch knows which
/// server's token to read — including after a sign-out, when there is none. The origin is no
/// secret; the app target keeps it in its defaults.
public protocol ActiveOriginStore: Sendable {
  func load() -> ServerOrigin?
  /// Nil clears it.
  func save(_ origin: ServerOrigin?)
}
