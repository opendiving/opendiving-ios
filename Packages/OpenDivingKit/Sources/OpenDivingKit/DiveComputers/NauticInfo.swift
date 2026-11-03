import Foundation

/// A Suunto Nautic-family watch's `/Info`: NUL-terminated strings among binary fields — vendor,
/// product, codename, serial, firmware, the radios' addresses.
public enum NauticInfo {
  public static let path = "/Info"

  /// The firmware as libdivecomputer's device info packs it, `a << 16 | b << 8 | c`, from the
  /// first `a.b.c` string, each part under 256; nil where there is none.
  public static func firmware(_ info: Data) -> UInt32? {
    var start = info.startIndex
    for index in info.indices where info[index] == 0 {
      if let version = version(info[start..<index]) { return version }
      start = info.index(after: index)
    }
    return nil
  }

  private static func version(_ token: Data) -> UInt32? {
    let parts = token.split(separator: UInt8(ascii: "."), omittingEmptySubsequences: false)
    guard parts.count == 3 else { return nil }
    var packed: UInt32 = 0
    for part in parts {
      guard (1...3).contains(part.count), part.allSatisfy({ (0x30...0x39).contains($0) }),
        let value = UInt32(String(decoding: part, as: UTF8.self)), value < 256
      else { return nil }
      packed = packed << 8 | value
    }
    return packed
  }
}
