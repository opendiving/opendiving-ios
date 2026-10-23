import Foundation

/// The cached check-in sheet of one server, inside that server's directory: `sheet.json` and
/// a `files` folder holding the portrait and each card side.
///
/// A new sheet is written whole into a staging folder beside it and swapped in only once
/// every read and every file has landed, so a refresh that fails halfway leaves the previous
/// sheet exactly as it was. Sign-out leaves the folder alone; ``ServerStateStore/forget(_:)``
/// removes it with the server's directory.
public struct CheckinSheetStore: Sendable {
  /// The sheet's own folder.
  let root: URL

  /// `serverDirectory` is ``ServerStateStore/directory(for:)`` of the server the sheet
  /// came from.
  public init(serverDirectory: URL) {
    root = serverDirectory.appendingPathComponent("CheckinSheet", isDirectory: true)
  }

  public init(store: ServerStateStore, origin: ServerOrigin) {
    self.init(serverDirectory: store.directory(for: origin))
  }

  private var staging: URL { sibling("CheckinSheet.staging") }
  /// Where the swap parks the sheet it replaces, for the instant between the two moves.
  private var previous: URL { sibling("CheckinSheet.previous") }

  /// The cached sheet, or nil when this server has none.
  public func load() -> CheckinSheet? {
    guard let data = try? Data(contentsOf: Self.sheetFile(in: readable)) else { return nil }
    return try? APICoding.decoder().decode(CheckinSheet.self, from: data)
  }

  /// The bytes of a picture the cached sheet names.
  public func data(for file: CheckinSheetFile) -> Data? {
    try? Data(contentsOf: Self.file(file.name, in: readable))
  }

  /// The current folder, or the parked one when a swap was interrupted between its moves.
  private var readable: URL {
    exists(root) || !exists(previous) ? root : previous
  }

  // MARK: - Writing

  /// A sheet being assembled, invisible to ``load()`` until ``commit(_:)``.
  struct Staging {
    let root: URL
    let current: URL

    /// Writes freshly fetched bytes.
    func write(_ data: Data, name: String) throws {
      try data.write(to: CheckinSheetStore.file(name, in: root), options: .atomic)
    }

    /// Carries a file the server answered 304 for over from the current sheet.
    func carry(name: String) throws {
      try FileManager.default.copyItem(
        at: CheckinSheetStore.file(name, in: current), to: CheckinSheetStore.file(name, in: root))
    }
  }

  func beginStaging() throws -> Staging {
    try removeIfPresent(staging)
    try FileManager.default.createDirectory(
      at: staging.appendingPathComponent("files", isDirectory: true),
      withIntermediateDirectories: true)
    return Staging(root: staging, current: readable)
  }

  /// Writes `sheet` into the staging folder and swaps it in for the current one.
  func commit(_ sheet: CheckinSheet) throws {
    try APICoding.encoder().encode(sheet).write(to: Self.sheetFile(in: staging), options: .atomic)
    let manager = FileManager.default
    try removeIfPresent(previous)
    if exists(root) {
      try manager.moveItem(at: root, to: previous)
    }
    try manager.moveItem(at: staging, to: root)
    try? manager.removeItem(at: previous)
  }

  func discardStaging() {
    try? removeIfPresent(staging)
  }

  /// Whether the current sheet holds a file by this name, so that its stored `ETag` can be
  /// sent.
  func hasFile(_ name: String) -> Bool {
    exists(Self.file(name, in: readable))
  }

  // MARK: - Paths

  private static func sheetFile(in folder: URL) -> URL {
    folder.appendingPathComponent("sheet.json", isDirectory: false)
  }

  fileprivate static func file(_ name: String, in folder: URL) -> URL {
    folder.appendingPathComponent("files", isDirectory: true)
      .appendingPathComponent(name, isDirectory: false)
  }

  private func sibling(_ name: String) -> URL {
    root.deletingLastPathComponent().appendingPathComponent(name, isDirectory: true)
  }

  private func exists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path)
  }

  private func removeIfPresent(_ url: URL) throws {
    guard exists(url) else { return }
    try FileManager.default.removeItem(at: url)
  }
}
