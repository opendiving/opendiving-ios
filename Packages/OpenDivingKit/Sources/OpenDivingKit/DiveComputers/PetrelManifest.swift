import Foundation

/// A Shearwater Petrel-family computer's dive index, read before any dive: pages of 32-byte
/// records, newest first, at ``address``. Each record is big-endian — a marker, the dive number,
/// the start (the dive's fingerprint), the end, the dive time, the depths, the dive's address
/// from the log format's base — and the first record with neither marker ends the index.
public enum PetrelManifest {
  /// Where the index is read, one ``pageSize`` page per read; the computer serves the next page
  /// on the next read.
  public static let address: UInt32 = 0xE000_0000
  public static let pageSize = 0x600
  public static let recordSize = 32
  public static let recordsPerPage = 48

  public struct Record: Hashable, Sendable {
    /// A dive the diver deleted on the computer, which stays in the index.
    public let isDeleted: Bool
    /// The start's four bytes, as the dive's own bytes 12 to 15 carry them: its fingerprint.
    public let start: Data
    /// The dive's address, from the log format's base (``PetrelIdentifier/logBase(_:)``).
    public let address: UInt32

    public init(isDeleted: Bool, start: Data, address: UInt32) {
      self.isDeleted = isDeleted
      self.start = start
      self.address = address
    }
  }

  /// One page's records, up to the first that is neither a dive nor a deleted one.
  public struct Page: Hashable, Sendable {
    public let records: [Record]

    /// Another page follows: this one holds a record in every slot.
    public var continues: Bool { records.count == PetrelManifest.recordsPerPage }

    public init(_ bytes: Data) {
      let data = [UInt8](bytes)
      var records: [Record] = []
      var offset = 0
      while offset + PetrelManifest.recordSize <= data.count,
        records.count < PetrelManifest.recordsPerPage
      {
        let marker = UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
        guard marker == PetrelManifest.live || marker == PetrelManifest.deleted else { break }
        let address = data[(offset + 20)..<(offset + 24)].reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        records.append(
          Record(
            isDeleted: marker == PetrelManifest.deleted,
            start: Data(data[(offset + 4)..<(offset + 8)]), address: address))
        offset += PetrelManifest.recordSize
      }
      self.records = records
    }
  }

  /// What a walk over these records, every page's in order, takes with `fingerprint` set.
  public struct Selection: Hashable, Sendable {
    /// The live records the walk downloads, newest first.
    public let new: [Record]
    public let listing: DiveComputerListing
  }

  /// The live records before the one whose start is `fingerprint`, or every live one where none
  /// is, as libdivecomputer's walk compares — deleted records skipped wherever they sit. Unlike
  /// libdivecomputer, which keeps a page's first records by count and so can drop live ones
  /// where deleted ones sit among them, every live record is kept.
  public static func select(_ records: [Record], fingerprint: Data?) -> Selection {
    let live = records.filter { !$0.isDeleted }
    let stop = fingerprint.flatMap { mark in live.firstIndex { $0.start == mark } }
    let new = Array(live[..<(stop ?? live.endIndex)])
    return Selection(
      new: new,
      listing: DiveComputerListing(dives: live.count, newDives: new.count, newEntries: new.count))
  }

  static let live: UInt16 = 0xA5C4
  static let deleted: UInt16 = 0x5A23
}
