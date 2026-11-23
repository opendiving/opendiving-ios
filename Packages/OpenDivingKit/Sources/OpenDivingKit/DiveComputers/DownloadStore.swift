import Foundation

/// One account's downloads on the phone, under `Downloads/` in its directory: the walks whose
/// dives are being kept as they arrive or wait for a time zone, each a record beside a folder of
/// the dives' bytes; the archives waiting to be imported, each a record beside its zip; and, per
/// computer, the dives the server has answered for and, apart, those the diver did not choose to
/// download, which a walk does not take again until the computer's fingerprint has passed them.
///
/// A record this build cannot read is kept and never overwritten (``KeptFolder``), and the bytes
/// beside it with it.
public struct DownloadStore: Sendable {
  public let account: UUID
  let root: URL
  private let walkRecords: KeptFolder<KeptWalk>
  private let archiveRecords: KeptFolder<DownloadArchive>
  private let deliveredRecords: KeptFolder<[UUID]>
  private let declinedRecords: KeptFolder<[UUID]>

  public init(store: ServerStateStore, origin: ServerOrigin, account: UUID) {
    self.account = account
    root = store.directory(for: origin, account: account)
      .appendingPathComponent("Downloads", isDirectory: true)
    walkRecords = KeptFolder(url: root.appendingPathComponent("Walks", isDirectory: true))
    archiveRecords = KeptFolder(url: root.appendingPathComponent("Archives", isDirectory: true))
    deliveredRecords = Self.delivered(in: root)
    declinedRecords = Self.declined(in: root)
  }

  private static func delivered(in root: URL) -> KeptFolder<[UUID]> {
    KeptFolder(url: root.appendingPathComponent("Delivered", isDirectory: true))
  }

  private static func declined(in root: URL) -> KeptFolder<[UUID]> {
    KeptFolder(url: root.appendingPathComponent("Declined", isDirectory: true))
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

  /// The archives waiting, oldest download first, a walk's in the order they were cut.
  public func archives() -> [DownloadArchive] {
    archiveRecords.load().values.map(\.value).sorted {
      ($0.summary.downloadedAt, $0.part ?? 0, $0.id.uuidString)
        < ($1.summary.downloadedAt, $1.part ?? 0, $1.id.uuidString)
    }
  }

  /// Where an archive's zip is.
  public func url(for archive: DownloadArchive) -> URL {
    root.appendingPathComponent("Archives", isDirectory: true)
      .appendingPathComponent(archive.id.uuidString.lowercased() + ".zip", isDirectory: false)
  }

  /// Takes the written zip in and records it: the bytes first, so a record never names a zip
  /// that is not there. `walk` and `part` place it among the archives cut from one walk; `facts`
  /// is what the list said of its dives.
  func add(
    _ written: ComputerArchiveWriter.Written, record: String, marked: Bool, walk: UUID? = nil,
    part: Int? = nil, facts: [UUID: ListedDiveFacts] = [:]
  ) throws -> DownloadArchive {
    let archive = DownloadArchive(
      filename: written.url.lastPathComponent, summary: written.summary, record: record,
      dives: written.dives, receivedBeforeAccountKnown: marked, walk: walk, part: part,
      facts: facts.filter { written.dives.contains($0.key) })
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

  // MARK: - What the server answered for, and what the diver did not choose

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

  /// Every computer's dives the diver did not choose since its fingerprint last moved. Kept apart
  /// from what the server answered for: they are the diver's whichever account loads, and leave
  /// with the computer when it is forgotten.
  func allDeclined() -> Set<UUID> {
    Set(declinedRecords.load().values.flatMap(\.value))
  }

  /// The diver chose from a computer's list: what they did not choose is not taken again, and
  /// what they chose is taken whatever an earlier choice or answer left out.
  func choose(_ chosen: [UUID], declined: [UUID], of record: String) throws {
    let answered = delivered(record).subtracting(chosen)
    try deliveredRecords.write(answered.sorted { $0.uuidString < $1.uuidString }, name: record)
    try declinedRecords.write(declined.sorted { $0.uuidString < $1.uuidString }, name: record)
  }

  /// The computer's fingerprint moved past every dive a complete walk saw, these among them.
  func clearDelivered(_ record: String) {
    deliveredRecords.remove(record)
    declinedRecords.remove(record)
  }

  /// *Forget this dive computer*: what any account's diver chose not to download from it goes
  /// with it, so pairing it again asks afresh. So does what the server answered for, which stands
  /// in for the fingerprint until it moves: left behind, the next walk would pass those dives over
  /// without asking the server, and so could not say that the logbook holds them.
  static func forgetComputer(_ record: String, store: ServerStateStore) {
    for directory in store.accountDirectories() {
      let downloads = directory.appendingPathComponent("Downloads", isDirectory: true)
      delivered(in: downloads).remove(record)
      declined(in: downloads).remove(record)
    }
  }

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
