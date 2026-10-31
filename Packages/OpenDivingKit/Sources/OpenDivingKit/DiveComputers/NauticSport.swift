import Foundation

/// The sport a Suunto Nautic-family logbook entry was recorded as. The Ocean is a sports watch,
/// and its logbook lists every activity it recorded, runs beside dives.
///
/// An entry is the SBEM stream the backend delivers: the `SBEM0103` magic, then TLV records — a
/// one-byte id, a one-byte length (255: a four-byte little-endian length follows), the value —
/// and possibly a second `SBEM0103` section, the summary, appended after the profile. The
/// activity record, id `0x08`, is `[time delta: Int16 LE][sport id: UInt8][custom mode id:
/// NUL-terminated ASCII]`; its length follows the mode id's, 6 for scuba's `51`, 5 for
/// running's `3`.
public enum NauticSport {
  /// Suunto's activity ids for the diving sports: 51 scuba, 61 freediving, 62 mermaiding, the
  /// ids libdivecomputer's Nautic parser names from the Suunto app's activity types. An id
  /// outside them — 3, running — is not a dive.
  public static let diving: Set<Int> = [51, 61, 62]

  /// Whether the entry is a dive: its sport is a diving one, or it names none. An entry with no
  /// activity record is kept, since a dive wrongly skipped is never walked again once the
  /// fingerprint moves past it, while an activity wrongly kept can be deleted.
  public static func isDive(_ bytes: Data) -> Bool {
    id(in: bytes).map(diving.contains) ?? true
  }

  /// The sport id of the profile's first activity record; nil where the stream is not SBEM or
  /// carries none.
  public static func id(in bytes: Data) -> Int? {
    let data = [UInt8](bytes)
    guard data.count >= magic.count, Array(data[0..<magic.count]) == magic else { return nil }
    let end = summaryStart(data)
    var position = magic.count
    while position + 2 <= end {
      let id = data[position]
      var length = Int(data[position + 1])
      var header = 2
      if length == 255 {
        guard position + 6 <= end else {
          position += 1
          continue
        }
        length = (0..<4).reduce(0) { $0 | Int(data[position + 2 + $1]) << (8 * $1) }
        header = 6
      }
      // A header whose id has a fixed length and names another, or that overruns the profile,
      // is an artefact of the watch's decompression rather than a record: step past one byte,
      // as libdivecomputer's parser does.
      if let fixed = fixedLengths[id], fixed != length {
        position += 1
        continue
      }
      let start = position + header
      guard start + length <= end else {
        position += 1
        continue
      }
      if id == activity, let sport = sport(data[start..<(start + length)]) { return sport }
      position = start + length
    }
    return nil
  }

  private static let magic = Array("SBEM0103".utf8)
  private static let activity: UInt8 = 0x08
  /// libdivecomputer's table of records whose length never varies, less the activity record,
  /// whose length it fixes at 6 though a one-digit mode id makes it 5.
  private static let fixedLengths: [UInt8: Int] = [0x0B: 20, 0x0E: 6, 0x14: 7, 0x17: 14]

  /// The sport id of an activity record whose mode id is ASCII ending in a NUL; nil for one
  /// shaped otherwise, which is read as no activity record at all.
  private static func sport(_ value: ArraySlice<UInt8>) -> Int? {
    guard value.count >= 4, value.last == 0 else { return nil }
    let mode = value.dropFirst(3).dropLast()
    guard mode.allSatisfy({ (0x20...0x7E).contains($0) }) else { return nil }
    return Int(value[value.startIndex + 2])
  }

  private static func summaryStart(_ data: [UInt8]) -> Int {
    var index = magic.count
    while index + magic.count <= data.count {
      if data[index] == magic[0], Array(data[index..<(index + magic.count)]) == magic {
        return index
      }
      index += 1
    }
    return data.count
  }
}
