import Foundation

/// The instance's map tiles the phone has shown, and the credit they owe, kept in the server's
/// directory so a page head draws at once and offline, and `forget` removes them with the rest
/// of the server's. Nobody's data: one tile serves every account, and a phone restored from a
/// backup asks for it again, so the directory is left out of backups.
///
/// A held tile is shown as it is and asked for again once per launch with its `ETag`, which is
/// how a redeployed renderer's tiles reach the phone. The newest ``keptTiles`` stay, counted
/// when the store first writes.
public actor MapTileStore {
  /// A tile not drawn yet holds its request open for the draw, and the rest of the app needs
  /// connections to the same host; the web keeps the same four.
  static let concurrentRequests = 4
  /// About a hundred page heads at four tiles each.
  static let keptTiles = 400

  public nonisolated let client: APIClient
  private let directory: URL
  private let language: String?
  private var asked: Set<MapTileAddress> = []
  private var pruned = false
  private var active = 0
  private var queue: [(id: UUID, continuation: CheckedContinuation<Void, any Error>)] = []

  /// `language` is the reader's, as a BCP 47 tag; the API reduces it to one its labels carry.
  public init(client: APIClient, directory: URL, language: String?) {
    self.client = client
    self.directory = directory
    self.language = language.flatMap { $0.isEmpty ? nil : $0 }
  }

  /// The tile as the phone holds it, asking nothing.
  public func stored(_ address: MapTileAddress) -> Data? {
    let file = tileFile(address)
    guard let data = try? Data(contentsOf: file) else { return nil }
    try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
    return data
  }

  /// Those of `addresses` the server has not been asked for since launch.
  public func notAsked(among addresses: Set<MapTileAddress>) -> Set<MapTileAddress> {
    addresses.subtracting(asked)
  }

  /// The tile from the server, or the one held when the server's is unchanged or cannot be
  /// had; nil when neither is there.
  public func fetch(_ address: MapTileAddress) async -> Data? {
    let held = try? Data(contentsOf: tileFile(address))
    let etag = held == nil ? nil : try? String(contentsOf: etagFile(address), encoding: .utf8)
    do {
      try Task.checkCancellation()
      try await acquire()
      defer { release() }
      let answer = try await client.mapTile(address, language: language, etag: etag)
      asked.insert(address)
      switch answer {
      case .notModified:
        return held
      case .fetched(let bytes, let etag):
        write(bytes.data, etag: etag, for: address)
        return bytes.data
      }
    } catch {
      return held
    }
  }

  /// The credit the instance last named for its tiles.
  public func credit() -> String? {
    try? String(contentsOf: creditFile, encoding: .utf8)
  }

  public func remember(credit: String) {
    guard credit != self.credit() else { return }
    makeDirectory()
    try? Data(credit.utf8).write(to: creditFile, options: .atomic)
  }

  // MARK: - Files

  private func makeDirectory() {
    var directory = directory
    guard (try? directory.checkResourceIsReachable()) != true else { return }
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? directory.setResourceValues(values)
  }

  private var creditFile: URL {
    directory.appendingPathComponent("credit.txt", isDirectory: false)
  }

  private func tileFile(_ address: MapTileAddress) -> URL {
    directory.appendingPathComponent(name(address) + ".webp", isDirectory: false)
  }

  private func etagFile(_ address: MapTileAddress) -> URL {
    directory.appendingPathComponent(name(address) + ".etag", isDirectory: false)
  }

  private func name(_ address: MapTileAddress) -> String {
    // A tag is letters, digits and hyphens; anything else is not a file name's business.
    let tag = (language ?? "none").filter {
      $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-")
    }
    return "\(address.theme.rawValue)-\(tag)-\(address.z)-\(address.x)-\(address.y)"
  }

  private func write(_ data: Data, etag: String?, for address: MapTileAddress) {
    let manager = FileManager.default
    makeDirectory()
    if !pruned {
      prune()
      pruned = true
    }
    try? data.write(to: tileFile(address), options: .atomic)
    if let etag {
      try? Data(etag.utf8).write(to: etagFile(address), options: .atomic)
    } else {
      try? manager.removeItem(at: etagFile(address))
    }
  }

  /// Removes all but the newest ``keptTiles``, by when each was last shown.
  private func prune() {
    let manager = FileManager.default
    guard
      let files = try? manager.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
    else { return }
    let tiles = files.filter { $0.pathExtension == "webp" }
    guard tiles.count > Self.keptTiles else { return }
    let shown = { (file: URL) in
      (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
        ?? .distantPast
    }
    for file in tiles.sorted(by: { shown($0) > shown($1) }).dropFirst(Self.keptTiles) {
      try? manager.removeItem(at: file)
      try? manager.removeItem(at: file.deletingPathExtension().appendingPathExtension("etag"))
    }
  }

  // MARK: - Requests out

  private func acquire() async throws {
    if active < Self.concurrentRequests {
      active += 1
      return
    }
    let id = UUID()
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        queue.append((id, continuation))
      }
    } onCancel: {
      Task { await self.withdraw(id) }
    }
  }

  /// A page head that left the screen gives up its place in the queue.
  private func withdraw(_ id: UUID) {
    guard let index = queue.firstIndex(where: { $0.id == id }) else { return }
    queue.remove(at: index).continuation.resume(throwing: CancellationError())
  }

  /// Hands the slot to the next in the queue, or frees it.
  private func release() {
    if queue.isEmpty {
      active -= 1
    } else {
      queue.removeFirst().continuation.resume()
    }
  }
}
