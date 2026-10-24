import Foundation

/// Gets a file handed to the app into a place the inbox can move it from. The copy iOS made in
/// the app's own `Documents/Inbox` is used as it is; anything else — a file the picker or
/// another app lends — is copied out under its security scope, held only for that copy, into
/// a staging folder of its own so two files of one name stay two.
enum SharedFileStaging {
  static func stage(_ url: URL) -> URL? {
    guard url.isFileURL else { return nil }
    if isInOwnInbox(url) { return url }
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    let folder = FileManager.default.temporaryDirectory
      .appendingPathComponent("SharedFiles", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let copy = folder.appendingPathComponent(url.lastPathComponent, isDirectory: false)
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      try FileManager.default.copyItem(at: url, to: copy)
      return copy
    } catch {
      return nil
    }
  }

  private static func isInOwnInbox(_ url: URL) -> Bool {
    let inbox = URL.documentsDirectory.appendingPathComponent("Inbox", isDirectory: true)
      .resolvingSymlinksInPath().path
    return url.resolvingSymlinksInPath().path.hasPrefix(inbox + "/")
  }
}
