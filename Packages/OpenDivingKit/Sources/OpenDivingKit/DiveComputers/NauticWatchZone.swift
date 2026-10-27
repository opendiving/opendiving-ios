import Foundation

/// A Suunto Nautic's own time zone, decoded from the settings resources the Suunto app reads
/// it from. The dives carry no offset, so this is what puts a download's starts in the zone
/// the watch was set to.
///
/// Each resource is as libdc-swift's `SuuntoNauticExplorer.fetch` returns it: a two-byte
/// sequence number, the eight-byte reply header, the value, and a four-byte checksum. The value
/// is framed `[type: UInt16 LE][payload]`, types 1 to 8 being integers.
/// `TimeZoneInfo` is a structure whose payload carries the zone's identifier as a
/// NUL-terminated string, `Africa/Cairo`; `LocalTime/Offset` is an `Int16` of minutes east of
/// UTC. `LocalTime/TimeZone` is refused by the Ocean and `/Dev/Time` is the clock, so neither is
/// read.
public enum NauticWatchZone {
  public static let zoneInfoPath = "/Settings/General/TimeZoneInfo"
  public static let offsetPath = "/Settings/User/Time/LocalTime/Offset"
  /// What the conformance fetches, in the order it is read.
  public static let paths = [zoneInfoPath, offsetPath]

  /// The zone by its identifier where the watch carries one, else by its offset; nil where
  /// neither resource reads, and the diver is asked instead.
  public static func decode(_ resources: [String: Data]) -> TimeZone? {
    if let info = resources[zoneInfoPath].flatMap(value), let zone = identifier(in: info.payload) {
      return zone
    }
    guard let offset = resources[offsetPath].flatMap(value), let minutes = integer(offset),
      abs(minutes) <= 18 * 60
    else { return nil }
    return TimeZone(secondsFromGMT: minutes * 60)
  }

  private static let headerSize = 10
  private static let checksumSize = 4

  static func value(_ fetched: Data) -> (type: UInt16, payload: Data)? {
    let bytes = [UInt8](fetched)
    guard bytes.count >= headerSize + 2 + checksumSize else { return nil }
    let value = bytes[headerSize..<(bytes.count - checksumSize)]
    let type = UInt16(value[value.startIndex]) | UInt16(value[value.startIndex + 1]) << 8
    return (type, Data(value.dropFirst(2)))
  }

  /// The zone a NUL-terminated string names. Its start is not marked: the bytes before it are
  /// a transition time, whose last byte can be printable (`k` before `Africa/Cairo` in the
  /// capture), so each run of printable ASCII is tried from each of its characters, longest
  /// first.
  static func identifier(in payload: Data) -> TimeZone? {
    let runs = payload.split(whereSeparator: { !(0x21...0x7E).contains($0) })
    for run in runs {
      for start in run.indices where run.endIndex - start >= 3 {
        let name = String(decoding: run[start...], as: UTF8.self)
        if let zone = TimeZone(identifier: name), zone.identifier == name { return zone }
      }
    }
    return nil
  }

  /// An integer value: types 1 and 3 are one unsigned byte, 2 a signed one, 4 and 5 a signed
  /// and an unsigned `UInt16`, 6 and 7 the same in 32 bits, 8 a signed 64-bit integer.
  static func integer(_ value: (type: UInt16, payload: Data)) -> Int? {
    let bytes = [UInt8](value.payload)
    func little(_ count: Int) -> UInt64? {
      guard bytes.count >= count else { return nil }
      return (0..<count).reduce(UInt64(0)) { $0 | UInt64(bytes[$1]) << (8 * UInt64($1)) }
    }
    switch value.type {
    case 1, 3: return little(1).map { Int($0) }
    case 2: return little(1).map { Int(Int8(truncatingIfNeeded: $0)) }
    case 4: return little(2).map { Int(Int16(truncatingIfNeeded: $0)) }
    case 5: return little(2).map { Int($0) }
    case 6: return little(4).map { Int(Int32(truncatingIfNeeded: $0)) }
    case 7: return little(4).map { Int($0) }
    case 8: return little(8).map { Int(Int64(bitPattern: $0)) }
    default: return nil
    }
  }
}
