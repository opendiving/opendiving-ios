import Foundation

/// Writes a zip of stored — uncompressed — members to a file, one member at a time, so an
/// archive never has to sit in memory whole. Stored because a reader then needs no inflater and
/// the Kit needs no compression library Linux's Foundation lacks.
struct ZipWriter {
  private struct Entry {
    let name: [UInt8]
    let crc: UInt32
    let size: UInt32
    let offset: UInt32
  }

  private let handle: FileHandle
  private let dosTime: UInt16
  private let dosDate: UInt16
  private var entries: [Entry] = []
  private var offset: UInt64 = 0

  /// Members carry `moment` as their modification time, in `zone`'s wall clock, as zip does.
  init(creating url: URL, moment: Date, zone: TimeZone) throws {
    guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
      throw CocoaError(.fileWriteUnknown)
    }
    handle = try FileHandle(forWritingTo: url)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    let parts = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second], from: moment)
    let year = max(0, min(127, parts.year! - 1980))
    dosDate = UInt16(year << 9 | parts.month! << 5 | parts.day!)
    dosTime = UInt16(parts.hour! << 11 | parts.minute! << 5 | parts.second! / 2)
  }

  mutating func add(_ name: String, _ bytes: Data) throws {
    guard bytes.count < Int(UInt32.max), offset < UInt64(UInt32.max) else {
      throw ZipError.tooLarge
    }
    let nameBytes = Array(name.utf8)
    let crc = CRC32.checksum(bytes)
    var header = Data()
    header.append(le32: 0x0403_4b50)
    header.append(le16: 20)
    header.append(le16: 0x0800)  // the name is UTF-8
    header.append(le16: 0)  // stored
    header.append(le16: dosTime)
    header.append(le16: dosDate)
    header.append(le32: crc)
    header.append(le32: UInt32(bytes.count))
    header.append(le32: UInt32(bytes.count))
    header.append(le16: UInt16(nameBytes.count))
    header.append(le16: 0)
    header.append(contentsOf: nameBytes)
    try handle.write(contentsOf: header)
    try handle.write(contentsOf: bytes)
    entries.append(
      Entry(name: nameBytes, crc: crc, size: UInt32(bytes.count), offset: UInt32(offset)))
    offset += UInt64(header.count + bytes.count)
  }

  /// Writes the central directory and closes the file.
  mutating func finish() throws {
    let start = offset
    var directory = Data()
    for entry in entries {
      directory.append(le32: 0x0201_4b50)
      directory.append(le16: 20)
      directory.append(le16: 20)
      directory.append(le16: 0x0800)
      directory.append(le16: 0)
      directory.append(le16: dosTime)
      directory.append(le16: dosDate)
      directory.append(le32: entry.crc)
      directory.append(le32: entry.size)
      directory.append(le32: entry.size)
      directory.append(le16: UInt16(entry.name.count))
      directory.append(le16: 0)
      directory.append(le16: 0)
      directory.append(le16: 0)
      directory.append(le16: 0)
      directory.append(le32: 0)
      directory.append(le32: entry.offset)
      directory.append(contentsOf: entry.name)
    }
    guard entries.count < Int(UInt16.max), start + UInt64(directory.count) < UInt64(UInt32.max)
    else { throw ZipError.tooLarge }
    var end = Data()
    end.append(le32: 0x0605_4b50)
    end.append(le16: 0)
    end.append(le16: 0)
    end.append(le16: UInt16(entries.count))
    end.append(le16: UInt16(entries.count))
    end.append(le32: UInt32(directory.count))
    end.append(le32: UInt32(start))
    end.append(le16: 0)
    try handle.write(contentsOf: directory + end)
    try handle.close()
  }
}

/// Why a zip could not be written or read.
enum ZipError: Error, Hashable, Sendable {
  /// Past what a zip without its 64-bit extension holds.
  case tooLarge
  /// Not a zip, or not one this reader follows.
  case unreadable
}

extension Data {
  mutating func append(le16 value: UInt16) {
    append(UInt8(value & 0xFF))
    append(UInt8(value >> 8))
  }

  mutating func append(le32 value: UInt32) {
    for shift in stride(from: 0, to: 32, by: 8) {
      append(UInt8(truncatingIfNeeded: value >> UInt32(shift)))
    }
  }
}
