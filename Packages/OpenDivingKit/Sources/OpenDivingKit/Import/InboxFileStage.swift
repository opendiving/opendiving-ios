import Foundation

/// Where one file in the inbox stands on its way to an import.
public enum InboxFileStage: Hashable, Sendable {
  /// Not uploaded: it goes with the next *Upload*.
  case waiting
  /// An upload is sending it.
  case uploading
  /// In an import the server holds, and kept here until that import is seen applied.
  case uploaded
  /// Left out, and why: by the bounds, or by the upload refusing its row.
  case refused(String)

  public var isRefused: Bool {
    if case .refused = self { true } else { false }
  }
}
