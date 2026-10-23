/// What the sign-in screen offers, besides signing in, while the phone is pointed at a server
/// and signed out of it. Nothing else is reachable signed out.
public enum SignedOutEntry: Hashable, Sendable, CaseIterable, Identifiable {
  /// The cached check-in sheet, which renders with no session.
  case checkInSheet
  /// Back to the server screen. The current server's cached sheet stays on the phone.
  case differentServer
  /// Everything kept for the server, removed — the one way to clear the sheet of a server that
  /// can no longer be signed in to.
  case forgetServer

  public var id: Self { self }
}
