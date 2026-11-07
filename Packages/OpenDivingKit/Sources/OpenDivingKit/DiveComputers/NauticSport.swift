import Foundation

/// The sport a Suunto Nautic-family logbook entry was recorded as. The Ocean is a sports watch,
/// and its logbook lists every activity it recorded, runs beside dives.
///
/// An entry is the SBEM stream the backend delivers: the `SBEM0103` magic, then records as
/// ``SBEMRecords`` reads them, and possibly a second `SBEM0103` section, the summary, appended
/// after the profile. The activity record, id `0x08`, is `[time delta: Int16 LE][sport id:
/// UInt8][custom mode id: NUL-terminated ASCII]`; its length follows the mode id's, 6 for scuba's
/// `51`, 5 for running's `3`.
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
  /// reaches a record that does not fit, or the profile's end, before one.
  public static func id(in bytes: Data) -> Int? {
    guard var records = SBEMRecords(bytes[..<summaryStart(bytes)]) else { return nil }
    while let record = records.next() {
      if record.id == activity, let sport = sport(record.value) { return sport }
    }
    return nil
  }

  private static let activity = 0x08

  /// The sport id of an activity record whose mode id is ASCII ending in a NUL; nil for one
  /// shaped otherwise, which is read as no activity record at all.
  private static func sport(_ value: Data.SubSequence) -> Int? {
    guard value.count >= 4, value.last == 0 else { return nil }
    let mode = value.dropFirst(3).dropLast()
    guard mode.allSatisfy({ (0x20...0x7E).contains($0) }) else { return nil }
    return Int(value[value.startIndex + 2])
  }

  /// Where the summary's magic is, searched for rather than walked to, so that a record
  /// overrunning the profile ends the walk instead of carrying it into the summary.
  private static func summaryStart(_ bytes: Data) -> Data.Index {
    let magic = SBEMRecords.magic
    var index = bytes.startIndex + magic.count
    while index + magic.count <= bytes.endIndex {
      if bytes[index] == magic[0], bytes[index...].starts(with: magic) { return index }
      index += 1
    }
    return bytes.endIndex
  }
}
