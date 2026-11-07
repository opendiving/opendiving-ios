import Foundation

/// A Suunto Nautic-family logbook entry's `/Descriptors`, which say how its `/Summary` is laid
/// out: what each record's group holds, field by field, and each field's format. The layout can
/// move between firmware versions, so the sport is found by its path rather than at an offset.
///
/// Both are SBEM streams, read by ``SBEMRecords``. A descriptor is a record of id 0: a two-byte
/// little-endian descriptor id, then lines `<PTH>path`, `<FRM>format`, or `<GRP>a,b,c` listing
/// the fields of a group. A summary record's id names a group, and its value is the group's
/// fields in order.
public struct NauticDescriptors: Sendable {
  public static func path(_ entry: UInt32) -> String { "/Logbook/byId/\(entry)/Descriptors" }
  public static func summaryPath(_ entry: UInt32) -> String { "/Logbook/byId/\(entry)/Summary" }

  private struct Field: Sendable {
    let path: String?
    let format: String
  }

  private var fields: [Int: Field] = [:]
  private var groups: [Int: [Int]] = [:]

  /// Bytes that are not descriptors define nothing, so every summary decodes to no sport.
  public init(_ bytes: Data) {
    guard let records = Self.records(bytes) else { return }
    for (id, value) in records where id == 0 && value.count >= 2 {
      let key = Int(value[value.startIndex]) | Int(value[value.startIndex + 1]) << 8
      let text = String(decoding: value.dropFirst(2), as: UTF8.self)
      var path: String?
      var format: String?
      for line in text.split(whereSeparator: { $0 == "\n" || $0 == "\0" }) {
        if line.hasPrefix("<PTH>") { path = String(line.dropFirst(5)) }
        if line.hasPrefix("<FRM>") { format = String(line.dropFirst(5)) }
        if line.hasPrefix("<GRP>") {
          groups[key] = line.dropFirst(5).split(separator: ",").compactMap { Int($0) }
        }
      }
      if let format { fields[key] = Field(path: path, format: format) }
    }
  }

  /// The sport a summary names: the integer at its field whose path ends `Header.ActivityType`,
  /// at the offset the group's fields before it add up to. Nil where no record carries that
  /// field, and where any record does not fit these descriptors — its id names no group, or
  /// its group's fields do not fill its bytes exactly — since then the offset cannot be trusted.
  public func sport(inSummary summary: Data) -> Int? {
    guard let records = Self.records(summary) else { return nil }
    var sport: Int?
    for (id, value) in records {
      guard let group = groups[id] else { return nil }
      var offset = value.startIndex
      for key in group {
        guard let field = fields[key], let size = Self.size(field.format, value[offset...])
        else { return nil }
        guard offset + size <= value.endIndex else { return nil }
        if sport == nil, field.path.map(Self.isActivityType) == true {
          sport = Self.integer(field.format, value[offset..<(offset + size)])
        }
        offset += size
      }
      guard offset == value.endIndex else { return nil }
    }
    return sport
  }

  /// The watch's hardware, `Seal_RevA3`: the label of the only value of the enumeration at the
  /// field whose path ends `Header.Device.Info.HW`, where a watch's descriptors name it. Nil where
  /// no field does.
  public var hardware: String? {
    fields.values.lazy.compactMap { field -> String? in
      guard field.path?.hasSuffix("Header.Device.Info.HW") == true,
        field.format.hasPrefix(Self.onlyValue)
      else { return nil }
      let label = field.format.dropFirst(Self.onlyValue.count).prefix { $0 != "," }
      return label.isEmpty ? nil : String(label)
    }.first
  }

  private static let onlyValue = "enum:0="

  private static func isActivityType(_ path: String) -> Bool {
    path == "Header.ActivityType" || path.hasSuffix(".Header.ActivityType")
  }

  private static let sizes: [String: Int] = [
    "local64": 8, "int64": 8, "uint64": 8, "float64": 8, "int32": 4, "uint32": 4, "float32": 4,
    "int16": 2, "uint16": 2, "int8": 1, "uint8": 1, "bool": 1, "d0": 0,
  ]

  /// A field's size in a value starting at its bytes: the format's own, a delta format's
  /// (`dint16`) its type's, an enumeration's one byte, a string's up to and with its NUL. Nil
  /// for a format not known here, or a string with no NUL.
  private static func size(_ format: String, _ bytes: Data.SubSequence) -> Int? {
    let base = format.prefix { $0 != "," }
    if base.hasPrefix("enum") { return 1 }
    if base == "utf8" { return bytes.firstIndex(of: 0).map { $0 - bytes.startIndex + 1 } }
    if let size = sizes[String(base)] { return size }
    if base.hasPrefix("d"), let size = sizes[String(base.dropFirst())] { return size }
    return nil
  }

  /// A little-endian integer field's value; nil for a format that is no integer.
  private static func integer(_ format: String, _ bytes: Data.SubSequence) -> Int? {
    let base = format.prefix { $0 != "," }
    let unsigned = bytes.reversed().reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
    let bits = UInt64(bytes.count * 8)
    switch base {
    case "uint8", "uint16", "uint32": return Int(unsigned)
    case "int8", "int16", "int32":
      let sign = UInt64(1) << (bits - 1)
      return unsigned & sign == 0 ? Int(unsigned) : Int(unsigned) - Int(sign << 1)
    default: return base.hasPrefix("enum") ? Int(unsigned) : nil
    }
  }

  /// The stream's records; nil where there is no magic or a record does not fit.
  private static func records(_ bytes: Data) -> [(id: Int, value: Data.SubSequence)]? {
    guard var walk = SBEMRecords(bytes) else { return nil }
    var records: [(id: Int, value: Data.SubSequence)] = []
    while let record = walk.next() { records.append(record) }
    return walk.isComplete ? records : nil
  }
}
