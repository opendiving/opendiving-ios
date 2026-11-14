import Foundation

/// One account's downloads on the phone, under `Downloads/` in its directory: the walks whose
/// dives are being kept as they arrive or wait for a time zone, each a record beside a folder of
/// the dives' bytes; the archives waiting to be imported, each a record beside its zip; and, per
/// computer, the dives the server has answered for, which a walk does not take again until the
/// computer's fingerprint has passed them.
///
/// A record this build cannot read is kept and never overwritten (``KeptFolder``), and the bytes
/// beside it with it.
public struct DownloadStore: Sendable {
  public let account: UUID
  let root: URL
  private let walkRecords: KeptFolder<KeptWalk>
  private let archiveRecords: KeptFolder<DownloadArchive>
  private let deliveredRecords: KeptFolder<[UUID]>

  public init(store: ServerStateStore, origin: ServerOrigin, account: UUID) {
    self.account = account
    root = store.directory(for: origin, account: account)
      .appendingPathComponent("Downloads", isDirectory: true)
    walkRecords = KeptFolder(url: root.appendingPathComponent("Walks", isDirectory: true))
    archiveRecords = KeptFolder(url: root.appendingPathComponent("Archives", isDirectory: true))
    deliveredRecords = KeptFolder(url: root.appendingPathComponent("Delivered", isDirectory: true))
  }

  /// The store of every account this server has a directory for.
  static func all(store: ServerStateStore, origin: ServerOrigin) -> [DownloadStore] {
    let accounts = store.directory(for: origin).appendingPathComponent(
      "Accounts", isDirectory: true)
    let names = (try? FileManager.default.contentsOfDirectory(atPath: accounts.path)) ?? []
    return names.compactMap(UUID.init(uuidString:)).map {
      DownloadStore(store: store, origin: origin, account: $0)
    }
  }

  // MARK: - Walks

  func walks() -> [KeptWalk] {
    walkRecords.load().values.map(\.value).sorted { ($0.startedAt, $0.id) < ($1.startedAt, $1.id) }
  }

  func walk(_ id: UUID) -> KeptWalk? { walkRecords.read(Self.name(id)) }

  func save(_ walk: KeptWalk) throws { try walkRecords.write(walk, name: Self.name(walk.id)) }

  /// Where a walk keeps its dives' bytes.
  func folder(of walk: UUID) -> URL {
    root.appendingPathComponent("Walks", isDirectory: true)
      .appendingPathComponent(walk.uuidString.lowercased(), isDirectory: true)
  }

  /// The walk's dives, rebuilt from disk; one whose bytes are gone is left out.
  func dives(of walk: KeptWalk) -> [DownloadedDive] {
    let folder = folder(of: walk.id)
    return walk.dives.compactMap { $0.downloaded(in: folder) }
  }

  func remove(walk id: UUID) {
    walkRecords.remove(Self.name(id))
    try? FileManager.default.removeItem(at: folder(of: id))
  }

  // MARK: - Archives

  /// The archives waiting, oldest download first.
  public func archives() -> [DownloadArchive] {
    archiveRecords.load().values.map(\.value).sorted {
      ($0.summary.downloadedAt, $0.id.uuidString) < ($1.summary.downloadedAt, $1.id.uuidString)
    }
  }

  /// Where an archive's zip is.
  public func url(for archive: DownloadArchive) -> URL {
    root.appendingPathComponent("Archives", isDirectory: true)
      .appendingPathComponent(archive.id.uuidString.lowercased() + ".zip", isDirectory: false)
  }

  /// Takes the written zip in and records it: the bytes first, so a record never names a zip
  /// that is not there.
  func add(_ written: ComputerArchiveWriter.Written, record: String, marked: Bool) throws
    -> DownloadArchive
  {
    let archive = DownloadArchive(
      filename: written.url.lastPathComponent, summary: written.summary, record: record,
      dives: written.dives, receivedBeforeAccountKnown: marked)
    let target = url(for: archive)
    try FileManager.default.createDirectory(
      at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.moveItem(at: written.url, to: target)
    do {
      try save(archive)
    } catch {
      try? FileManager.default.removeItem(at: target)
      throw error
    }
    return archive
  }

  func save(_ archive: DownloadArchive) throws {
    try archiveRecords.write(archive, name: Self.name(archive.id))
  }

  func remove(_ archive: DownloadArchive) {
    archiveRecords.remove(Self.name(archive.id))
    try? FileManager.default.removeItem(at: url(for: archive))
  }

  // MARK: - What the server answered for

  /// The dives of a computer the server has answered for since its fingerprint last moved.
  func delivered(_ record: String) -> Set<UUID> { Set(deliveredRecords.read(record) ?? []) }

  /// Every computer's dives the server has answered for.
  func allDelivered() -> Set<UUID> {
    Set(deliveredRecords.load().values.flatMap(\.value))
  }

  func deliver(_ dives: [UUID], of record: String) throws {
    let kept = delivered(record).union(dives)
    try deliveredRecords.write(kept.sorted { $0.uuidString < $1.uuidString }, name: record)
  }

  /// The computer's fingerprint moved past every dive a complete walk saw, these among them.
  func clearDelivered(_ record: String) { deliveredRecords.remove(record) }

  /// The dives the phone holds unimported under one mark: in an archive, or kept by a walk.
  /// Those kept under the other may yet move to another account.
  func waitingDives(marked: Bool) -> Set<UUID> {
    var dives = Set(
      archives().filter { $0.receivedBeforeAccountKnown == marked }.flatMap(\.dives))
    for walk in walks() where walk.receivedBeforeAccountKnown == marked {
      for dive in walk.dives {
        if let fingerprint = Hex.data(dive.fingerprint) {
          dives.insert(DiveComputerArchive.diveUUID(dive.identity, fingerprint: fingerprint))
        }
      }
    }
    return dives
  }

  // MARK: - Marks

  /// Moves what was kept before the account was known out of `other` and into this store,
  /// unmarked: copied and recorded here before it leaves there, so an interruption leaves an
  /// archive twice rather than nowhere.
  func takeMarked(from other: DownloadStore) throws {
    for archive in other.archives() where archive.receivedBeforeAccountKnown {
      var moved = archive
      moved.receivedBeforeAccountKnown = false
      let target = url(for: moved)
      try FileManager.default.createDirectory(
        at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
      try? FileManager.default.removeItem(at: target)
      try FileManager.default.copyItem(at: other.url(for: archive), to: target)
      try save(moved)
      other.remove(archive)
    }
    for walk in other.walks() where walk.receivedBeforeAccountKnown {
      var moved = walk
      moved.receivedBeforeAccountKnown = false
      let target = folder(of: walk.id)
      try FileManager.default.createDirectory(
        at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
      try? FileManager.default.removeItem(at: target)
      if FileManager.default.fileExists(atPath: other.folder(of: walk.id).path) {
        try FileManager.default.copyItem(at: other.folder(of: walk.id), to: target)
      }
      try save(moved)
      other.remove(walk: walk.id)
    }
  }

  /// Clears every mark: the account they were kept for is the one they stay with.
  func clearMarks() throws {
    for var archive in archives() where archive.receivedBeforeAccountKnown {
      archive.receivedBeforeAccountKnown = false
      try save(archive)
    }
    for var walk in walks() where walk.receivedBeforeAccountKnown {
      walk.receivedBeforeAccountKnown = false
      try save(walk)
    }
  }

  private static func name(_ id: UUID) -> String { id.uuidString.lowercased() + ".json" }
}
