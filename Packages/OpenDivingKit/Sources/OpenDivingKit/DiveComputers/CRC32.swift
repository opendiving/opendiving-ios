/// The zip format's CRC-32 (ISO 3309, reflected, polynomial `0xEDB88320`). The Kit writes its
/// own because nothing it imports on Linux has one; see DECISIONS.md, "The Kit computes its own
/// digests".
struct CRC32 {
  private(set) var value: UInt32 = 0

  private static let table: [UInt32] = (0..<256).map { index in
    var c = UInt32(index)
    for _ in 0..<8 {
      c = c & 1 == 1 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1
    }
    return c
  }

  mutating func update(_ bytes: some Sequence<UInt8>) {
    var c = ~value
    for byte in bytes {
      c = Self.table[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8)
    }
    value = ~c
  }

  static func checksum(_ bytes: some Sequence<UInt8>) -> UInt32 {
    var crc = CRC32()
    crc.update(bytes)
    return crc.value
  }
}
