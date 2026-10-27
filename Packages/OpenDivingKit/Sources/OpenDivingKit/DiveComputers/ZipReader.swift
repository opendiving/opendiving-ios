import Foundation

/// Reads a zip's central directory, and the bytes of a stored member: enough to tell whether a
/// waiting zip is a full-export archive, and to take a download archive's members into a union.
/// A compressed member is listed but not read, since the only archives read whole are the ones
/// ``ZipWriter`` wrote.
struct ZipReader {
  struct Entry: Hashable, Sendable {
    let name: String
    let method: UInt16
    let crc: UInt32
    let compressedSize: UInt64
    let size: UInt64
    let headerOffset: UInt64
  }

  let url: URL
  let entries: [Entry]

  init(_ url: URL) throws {
    self.url = url
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    let length = try handle.seekToEnd()
    let window = min(length, 65_535 + 22)
    try handle.seek(toOffset: length - window)
    let tail = [UInt8](try handle.readToEnd() ?? Data())
    guard tail.count >= 22,
      let end = stride(from: tail.count - 22, through: 0, by: -1).first(where: {
        tail.le32($0) == 0x0605_4b50
      })
    else { throw ZipError.unreadable }
    let count = Int(tail.le16(end + 10))
    let size = UInt64(tail.le32(end + 12))
    let start = UInt64(tail.le32(end + 16))
    guard start + size <= length else { throw ZipError.unreadable }
    try handle.seek(toOffset: start)
    let directory = [UInt8](try handle.read(upToCount: Int(size)) ?? Data())
    var entries: [Entry] = []
    var at = 0
    for _ in 0..<count {
      guard at + 46 <= directory.count, directory.le32(at) == 0x0201_4b50 else {
        throw ZipError.unreadable
      }
      let nameLength = Int(directory.le16(at + 28))
      let extraLength = Int(directory.le16(at + 30))
      let commentLength = Int(directory.le16(at + 32))
      guard at + 46 + nameLength <= directory.count else { throw ZipError.unreadable }
      entries.append(
        Entry(
          name: String(decoding: directory[(at + 46)..<(at + 46 + nameLength)], as: UTF8.self),
          method: directory.le16(at + 10), crc: directory.le32(at + 16),
          compressedSize: UInt64(directory.le32(at + 20)), size: UInt64(directory.le32(at + 24)),
          headerOffset: UInt64(directory.le32(at + 42))))
      at += 46 + nameLength + extraLength + commentLength
    }
    self.entries = entries
  }

  /// Whether `url` is a zip holding `logbook.divejson` at its root: a full-export archive, of
  /// which one import restores one.
  static func isFullExport(_ url: URL) -> Bool {
    ((try? ZipReader(url))?.entries ?? []).contains { $0.name == "logbook.divejson" }
  }

  /// A stored member's bytes, checked against its CRC-32.
  func read(_ entry: Entry) throws -> Data {
    guard entry.method == 0, entry.size == entry.compressedSize else { throw ZipError.unreadable }
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    try handle.seek(toOffset: entry.headerOffset)
    let header = [UInt8](try handle.read(upToCount: 30) ?? Data())
    guard header.count == 30, header.le32(0) == 0x0403_4b50 else { throw ZipError.unreadable }
    try handle.seek(
      toOffset: entry.headerOffset + 30 + UInt64(header.le16(26)) + UInt64(header.le16(28)))
    let bytes = try handle.read(upToCount: Int(entry.size)) ?? Data()
    guard bytes.count == Int(entry.size), CRC32.checksum(bytes) == entry.crc else {
      throw ZipError.unreadable
    }
    return bytes
  }
}

extension [UInt8] {
  fileprivate func le16(_ at: Int) -> UInt16 { UInt16(self[at]) | UInt16(self[at + 1]) << 8 }

  fileprivate func le32(_ at: Int) -> UInt32 {
    UInt32(self[at]) | UInt32(self[at + 1]) << 8 | UInt32(self[at + 2]) << 16
      | UInt32(self[at + 3]) << 24
  }
}
