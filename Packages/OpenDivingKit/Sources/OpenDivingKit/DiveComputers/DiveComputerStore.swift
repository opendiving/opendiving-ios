import Foundation

/// The dive computers paired with the phone, as one account sees them. The pairing is the phone's,
/// in ``ServerStateStore/diveComputersDirectory``, so a computer paired once is listed on every
/// server. How far a download got is the account's, in `DiveComputers/` in its directory: a
/// fingerprint is knowledge about one logbook, and shared it would stop a second server's first
/// download at dives that server has never seen. Both folders hold one file per computer, named by
/// family and serial. Sign-out leaves both; ``ServerStateStore/forget(_:)`` removes the server's
/// progress and leaves the pairing.
///
/// A file this build cannot decode is kept and never overwritten (``KeptFolder``).
public struct DiveComputerStore: Sendable {
  public let account: UUID
  private let store: ServerStateStore
  private let paired: KeptFolder<PairedComputer>
  private let progress: KeptFolder<DiveComputerProgress>

  public init(store: ServerStateStore, origin: ServerOrigin, account: UUID) {
    self.account = account
    self.store = store
    paired = KeptFolder(url: store.diveComputersDirectory)
    progress = Self.progress(in: store.directory(for: origin, account: account))
  }

  private static func progress(in account: URL) -> KeptFolder<DiveComputerProgress> {
    KeptFolder(url: account.appendingPathComponent("DiveComputers", isDirectory: true))
  }

  /// The store of every account this server has a directory for.
  static func all(store: ServerStateStore, origin: ServerOrigin) -> [DiveComputerStore] {
    let accounts = store.directory(for: origin).appendingPathComponent(
      "Accounts", isDirectory: true)
    let names = (try? FileManager.default.contentsOfDirectory(atPath: accounts.path)) ?? []
    return names.compactMap(UUID.init(uuidString:)).map {
      DiveComputerStore(store: store, origin: origin, account: $0)
    }
  }

  /// Pairs what an account's folder still holds as a whole record, the shape every computer was
  /// kept in before the pairing became the phone's. The newest download's copy wins where two
  /// accounts knew one computer. A progress file does not decode as a pairing, and *Forget* clears
  /// every account's folder, so running this again adds nothing.
  static func adoptAccountRecords(store: ServerStateStore) {
    let paired = KeptFolder<PairedComputer>(url: store.diveComputersDirectory)
    let found = store.accountDirectories().flatMap { directory in
      let folder = KeptFolder<PairedComputer>(
        url: directory.appendingPathComponent("DiveComputers", isDirectory: true))
      return folder.load().values.map { file in
        (file, progress(in: directory).read(file.name)?.lastDownloaded ?? .distantPast)
      }
    }
    for (file, _) in found.sorted(by: { $0.1 > $1.1 }) where !paired.contains(file.name) {
      try? paired.write(file.value, name: file.name)
    }
  }

  /// The phone's paired computers, read without an account: what the watch needs at a launch,
  /// before any session has loaded. Each record carries no account's progress.
  public static func pairings(applicationSupport: URL) -> [DiveComputerRecord] {
    KeptFolder<PairedComputer>(
      url: ServerStateStore.diveComputersDirectory(root: applicationSupport)
    ).load().values.map { DiveComputerRecord($0.value, progress: nil) }
  }

  /// Every readable record, by title.
  public func records() -> [DiveComputerRecord] {
    paired.load().values.map { record($0.value, name: $0.name) }.sorted {
      ($0.title, $0.serial) < ($1.title, $1.serial)
    }
  }

  private func record(_ computer: PairedComputer, name: String) -> DiveComputerRecord {
    DiveComputerRecord(computer, progress: progress.read(name))
  }

  /// How many pairings this build could not read.
  public var unreadableCount: Int { paired.load().unreadable.count }

  /// The record of the computer with this family and serial, whatever case the serial is in.
  public func record(family: DiveComputerFamily, serial: String) -> DiveComputerRecord? {
    let name = DiveComputerRecord.name(family: family, serial: serial)
    return paired.read(name).map { record($0, name: name) }
  }

  /// The record last seen under this Core Bluetooth identifier: the scan row's hint, for a
  /// computer whose name does not carry its serial.
  public func record(peripheral: UUID) -> DiveComputerRecord? {
    records().first { $0.peripheral == peripheral }
  }

  /// Writes the record, unless a file of its name is one this build could not read: a later
  /// build's record of the same computer is kept, and this one is not written.
  public func save(_ record: DiveComputerRecord) throws {
    if paired.contains(record.id), paired.read(record.id) == nil {
      throw DiveComputerStoreError.unreadableRecord
    }
    if progress.contains(record.id), progress.read(record.id) == nil {
      throw DiveComputerStoreError.unreadableRecord
    }
    try paired.write(PairedComputer(record), name: record.id)
    try progress.write(DiveComputerProgress(record), name: record.id)
  }

  /// Moves the record's Core Bluetooth hint to `peripheral`, writing the pairing alone: where the
  /// phone saw the computer says nothing about any account's logbook.
  public func follow(_ record: DiveComputerRecord, to peripheral: UUID) throws {
    guard paired.contains(record.id) else { return }
    guard var moved = paired.read(record.id) else {
      throw DiveComputerStoreError.unreadableRecord
    }
    moved.peripheral = peripheral
    try paired.write(moved, name: record.id)
  }

  /// *Forget this dive computer*: removes the pairing and every account's progress with it, and
  /// nothing on any server. Progress left behind would resume a computer the phone has forgotten.
  public func forget(_ record: DiveComputerRecord) {
    paired.remove(record.id)
    for directory in store.accountDirectories() {
      Self.progress(in: directory).remove(record.id)
    }
  }

  /// Removes the progress written before the account was known: the load named another account,
  /// and moved there it would carry this account's fingerprint into that one's. The computer stays
  /// paired, which says nothing about any logbook.
  func removeMarked() {
    for file in progress.load().values where file.value.receivedBeforeAccountKnown {
      progress.remove(file.name)
    }
  }

  /// Clears every mark: the account the progress was written for is the one it stays with.
  func clearMarks() throws {
    for var file in progress.load().values where file.value.receivedBeforeAccountKnown {
      file.value.receivedBeforeAccountKnown = false
      try progress.write(file.value, name: file.name)
    }
  }
}

/// Why a record was not written.
public enum DiveComputerStoreError: Error, Hashable, Sendable {
  /// The computer's file is one this build cannot read.
  case unreadableRecord
}
