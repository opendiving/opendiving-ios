import Foundation

/// The bounds the API certainly holds an import to, checked before anything is sent so a
/// diver is told no at once rather than after an upload. The API checks again regardless.
public enum ImportBounds {
  /// The largest file that is not a zip.
  public static let maxDocumentSize = 100 * 1024 * 1024
  /// The largest zip, and the largest request.
  public static let maxArchiveSize = 500 * 1024 * 1024
  public static let maxFiles = 1000

  /// Whether a file is a zip, by its name alone — used only to choose its bound. The API
  /// decides what the bytes are.
  public static func isZip(_ filename: String) -> Bool {
    filename.lowercased().hasSuffix(".zip")
  }

  /// Why one file certainly cannot be read, or nil. Such a file is shown refused in its own
  /// row and left out of the request; the rest still reads.
  public static func fileRefusal(filename: String, byteSize: Int) -> String? {
    if isZip(filename) {
      return byteSize > maxArchiveSize ? "A zip may be up to \(megabytes(maxArchiveSize))." : nil
    }
    return byteSize > maxDocumentSize
      ? "A file that is not a zip may be up to \(megabytes(maxDocumentSize)). Import the "
        + "full-export archive if you are restoring a whole account with its files."
      : nil
  }

  /// Why the files to be sent cannot go as one import, or nil.
  public static func selectionRefusal(byteSizes: [Int]) -> String? {
    if byteSizes.count > maxFiles {
      return "One import may carry up to \(maxFiles) files. Zip them and import the zip instead."
    }
    return byteSizes.reduce(0, +) > maxArchiveSize
      ? "One import may carry up to \(megabytes(maxArchiveSize)). Import these files in parts."
      : nil
  }

  private static func megabytes(_ bytes: Int) -> String {
    "\(bytes / (1024 * 1024)) MB"
  }
}
