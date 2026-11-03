/// Another app holding the computer, as the walk learns of it.
public enum DiveComputerBusy: Hashable, Sendable {
  /// The computer says it is busy with another app.
  case reported
  /// It says it is free again.
  case free
  /// Another app's handshake broke a transfer, which the walk waits out and tries again; nothing
  /// on the link says when the other app lets go.
  case otherApp
}
