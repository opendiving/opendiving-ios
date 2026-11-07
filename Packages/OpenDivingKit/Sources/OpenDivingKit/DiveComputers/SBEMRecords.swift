import Foundation

/// A strict walk over an SBEM stream: the `SBEM0103` magic, then records of an id (one byte; 0xFF:
/// a two-byte little-endian id follows), a length (one byte; 0xFF: a four-byte little-endian
/// length follows) and the value.
///
/// Each record says where the next one starts, so a record that does not fit ends the walk: past
/// it nothing can be told from a value's bytes, and ``isComplete`` stays false.
struct SBEMRecords: IteratorProtocol {
  static let magic = Data("SBEM0103".utf8)

  private let bytes: Data
  private var position: Data.Index

  /// Nil where the bytes do not open with the magic.
  init?(_ bytes: Data) {
    guard bytes.starts(with: Self.magic) else { return nil }
    self.bytes = bytes
    position = bytes.startIndex + Self.magic.count
  }

  /// Whether every byte has been walked, the last record ending exactly at the stream's end.
  var isComplete: Bool { position == bytes.endIndex }

  mutating func next() -> (id: Int, value: Data.SubSequence)? {
    var cursor = position
    guard let id = field(at: &cursor, escapedWidth: 2),
      let length = field(at: &cursor, escapedWidth: 4),
      length <= bytes.endIndex - cursor
    else { return nil }
    position = cursor + length
    return (id, bytes[cursor..<position])
  }

  /// The byte at the cursor, or where it is 0xFF the little-endian integer of `escapedWidth` bytes
  /// after it; nil where the stream ends first.
  private func field(at cursor: inout Data.Index, escapedWidth: Int) -> Int? {
    guard cursor < bytes.endIndex else { return nil }
    let first = bytes[cursor]
    cursor += 1
    guard first == 0xFF else { return Int(first) }
    guard escapedWidth <= bytes.endIndex - cursor else { return nil }
    defer { cursor += escapedWidth }
    return (0..<escapedWidth).reduce(0) { $0 | Int(bytes[cursor + $1]) << (8 * $1) }
  }
}
