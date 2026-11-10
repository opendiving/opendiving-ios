/// A deletion-pending sign-in's offer to bring the account back: the restore token, held in
/// memory for as long as the screen offering it, and written nowhere — not to a file, not to the
/// Keychain, not to a log. It prints as redacted wherever it is described, so a log line or a
/// dump of a sign-in step cannot carry it.
public struct RestoreOffer: Hashable, Sendable {
  let token: String
}

extension RestoreOffer: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
  public var description: String { "RestoreOffer(redacted)" }
  public var debugDescription: String { description }
  public var customMirror: Mirror { Mirror(self, children: [], displayStyle: .struct) }
}
