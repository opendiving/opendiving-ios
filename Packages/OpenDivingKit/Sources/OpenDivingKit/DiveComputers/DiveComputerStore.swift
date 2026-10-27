import Foundation

/// Where one account keeps the dive computers it has downloaded from: `DiveComputers/` in the
/// account's directory, one file per computer named by family and serial. A fingerprint is
/// knowledge about one account's logbook — another account on the same server has not imported
/// those dives — so it is the account's, not the server's or the phone's; sign-out leaves the
/// folder and ``ServerStateStore/forget(_:)`` removes it with the server's.
///
/// A file this build cannot decode is kept and never overwritten (``KeptFolder``).
public struct DiveComputerStore: Sendable {
  public let account: UUID
  private let folder: KeptFolder<DiveComputerRecord>

  public init(store: ServerStateStore, origin: ServerOrigin, account: UUID) {
    self.account = account
    folder = KeptFolder(
      url: store.directory(for: origin, account: account)
        .appendingPathComponent("DiveComputers", isDirectory: true))
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

  /// Every readable record, by title.
  public func records() -> [DiveComputerRecord] {
    folder.load().values.map(\.value).sorted {
      ($0.title, $0.serial) < ($1.title, $1.serial)
    }
  }

  /// How many records this build could not read.
  public var unreadableCount: Int { folder.load().unreadable.count }

  /// The record of the computer with this family and serial, whatever case the serial is in.
  public func record(family: DiveComputerFamily, serial: String) -> DiveComputerRecord? {
    folder.read(DiveComputerRecord.name(family: family, serial: serial))
  }

  /// The record last seen under this Core Bluetooth identifier: the scan row's hint, for a
  /// computer whose name does not carry its serial.
  public func record(peripheral: UUID) -> DiveComputerRecord? {
    records().first { $0.peripheral == peripheral }
  }

  /// Writes the record, unless a file of its name is one this build could not read: a later
  /// build's record of the same computer is kept, and this one is not written.
  public func save(_ record: DiveComputerRecord) throws {
    if folder.contains(record.id), folder.read(record.id) == nil {
      throw DiveComputerStoreError.unreadableRecord
    }
    try folder.write(record, name: record.id)
  }

  /// *Forget this dive computer*: removes the record, and nothing on the server.
  public func forget(_ record: DiveComputerRecord) {
    folder.remove(record.id)
  }

  /// Removes every record written before the account was known: the load named another
  /// account, and a record moved there would carry this account's fingerprint into that one's.
  func removeMarked() {
    for record in records() where record.receivedBeforeAccountKnown { forget(record) }
  }

  /// Clears every mark: the account the records were written for is the one they stay with.
  func clearMarks() throws {
    for var record in records() where record.receivedBeforeAccountKnown {
      record.receivedBeforeAccountKnown = false
      try save(record)
    }
  }
}

/// Why a record was not written.
public enum DiveComputerStoreError: Error, Hashable, Sendable {
  /// The computer's file is one this build cannot read.
  case unreadableRecord
}
