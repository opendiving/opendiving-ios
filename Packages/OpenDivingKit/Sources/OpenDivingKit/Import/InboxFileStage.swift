import Foundation

/// Where one waiting file stands on its way to an import.
public enum InboxFileStage: Hashable, Sendable {
  /// No read has covered it: the next read the app starts, or *Sync now*, sends it.
  case unread
  /// A read is sending it.
  case reading
  /// The inbox changed after the read that covered it, so it waits for *Read the files again*.
  case toReadAgain
  /// Read, and ready to import as the server read it: *FIT · kept on its dive*.
  case ready(String)
  /// Left out, and why: by the bounds, by the server refusing the read, or refusing its row.
  case refused(String)

  public var isRefused: Bool {
    if case .refused = self { true } else { false }
  }
}
