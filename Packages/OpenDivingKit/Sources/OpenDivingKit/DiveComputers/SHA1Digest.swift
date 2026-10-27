import Foundation

/// SHA-1 (FIPS 180-4), for the version-5 uuids a download's dives carry (RFC 9562 §5.5), and
/// nothing else: it is the hash that version names, not a security choice.
struct SHA1Digest {
  private var h: [UInt32] = [0x6745_2301, 0xEFCD_AB89, 0x98BA_DCFE, 0x1032_5476, 0xC3D2_E1F0]
  private var buffer: [UInt8] = []
  private var length: UInt64 = 0

  mutating func update(_ bytes: some Sequence<UInt8>) {
    for byte in bytes {
      buffer.append(byte)
      length &+= 1
      if buffer.count == 64 {
        compress(buffer)
        buffer.removeAll(keepingCapacity: true)
      }
    }
  }

  /// The digest, as 20 bytes. Consumes the state.
  mutating func finish() -> [UInt8] {
    let bits = length &* 8
    var tail = buffer
    tail.append(0x80)
    while tail.count % 64 != 56 { tail.append(0) }
    for shift in stride(from: 56, through: 0, by: -8) {
      tail.append(UInt8(truncatingIfNeeded: bits >> UInt64(shift)))
    }
    for start in stride(from: 0, to: tail.count, by: 64) {
      compress(Array(tail[start..<start + 64]))
    }
    return h.flatMap { word in
      (0..<4).map { UInt8(truncatingIfNeeded: word >> UInt32(24 - $0 * 8)) }
    }
  }

  static func digest(_ bytes: some Sequence<UInt8>) -> [UInt8] {
    var digest = SHA1Digest()
    digest.update(bytes)
    return digest.finish()
  }

  private mutating func compress(_ block: [UInt8]) {
    var w = [UInt32](repeating: 0, count: 80)
    for t in 0..<16 {
      w[t] =
        UInt32(block[t * 4]) << 24 | UInt32(block[t * 4 + 1]) << 16
        | UInt32(block[t * 4 + 2]) << 8 | UInt32(block[t * 4 + 3])
    }
    for t in 16..<80 {
      w[t] = (w[t - 3] ^ w[t - 8] ^ w[t - 14] ^ w[t - 16]).rotatedLeft(1)
    }
    var a = h[0]
    var b = h[1]
    var c = h[2]
    var d = h[3]
    var e = h[4]
    for t in 0..<80 {
      let f: UInt32
      let k: UInt32
      switch t {
      case 0..<20:
        f = (b & c) | (~b & d)
        k = 0x5A82_7999
      case 20..<40:
        f = b ^ c ^ d
        k = 0x6ED9_EBA1
      case 40..<60:
        f = (b & c) | (b & d) | (c & d)
        k = 0x8F1B_BCDC
      default:
        f = b ^ c ^ d
        k = 0xCA62_C1D6
      }
      let temp = a.rotatedLeft(5) &+ f &+ e &+ k &+ w[t]
      e = d
      d = c
      c = b.rotatedLeft(30)
      b = a
      a = temp
    }
    h[0] &+= a
    h[1] &+= b
    h[2] &+= c
    h[3] &+= d
    h[4] &+= e
  }
}

extension UUID {
  /// The version-5 uuid of `name` in `namespace` (RFC 9562 §5.5).
  static func version5(namespace: UUID, name: String) -> UUID {
    let space = withUnsafeBytes(of: namespace.uuid) { Array($0) }
    var bytes = Array(SHA1Digest.digest(space + Array(name.utf8)).prefix(16))
    bytes[6] = (bytes[6] & 0x0F) | 0x50
    bytes[8] = (bytes[8] & 0x3F) | 0x80
    return UUID(
      uuid: (
        bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8],
        bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
      ))
  }
}
