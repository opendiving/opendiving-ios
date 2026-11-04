import Foundation

/// The offset a Suunto Nautic logged a dive under, read from the head of the dive's bytes. The
/// watch sets its zone from GPS, so this is where the diver was, and it needs nothing else.
///
/// The bytes open `SBEM0103` and then record 1, the timeline's base, eight bytes in the format
/// the descriptors call `local64`: seven little-endian bytes of the wall clock in milliseconds,
/// then a signed byte of the offset from UTC in quarter hours.
enum NauticLoggedZone {
  private static let head = Data("SBEM0103".utf8) + [0x01, 0x08]

  /// The zone in `bytes`, for a dive that began at `instant`. Nil where they do not open with
  /// the base, or its clock less its offset is not that instant: every capture so far is east
  /// of UTC, so this is what stands behind the offset's sign.
  static func zone(in bytes: Data, at instant: Date) -> TimeZone? {
    guard bytes.starts(with: head), bytes.count >= head.count + 8 else { return nil }
    let value = [UInt8](bytes.dropFirst(head.count).prefix(8))
    let wallClock = value.prefix(7).reversed().reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
    let offset = Int(Int8(bitPattern: value[7])) * 15 * 60
    let logged = Double(wallClock) / 1000 - Double(offset)
    guard abs(logged - instant.timeIntervalSince1970) < 60 else { return nil }
    return TimeZone(secondsFromGMT: offset)
  }
}
