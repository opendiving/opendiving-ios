import Foundation

/// A Suunto Nautic-family logbook entry's `/Descriptors`, which say how its `/Summary` is laid
/// out: what each record's group holds, field by field, and each field's format. The layout can
/// move between firmware versions, so a field is found by its path rather than at an offset.
///
/// Both are SBEM streams, read by ``SBEMRecords``. A descriptor is a record of id 0: a two-byte
/// little-endian descriptor id, then lines `<PTH>path`, `<FRM>format`, `<MOD>x/1000` scaling the
/// raw value, or `<GRP>a,b,c` listing the fields of a group. A summary record's id names a group, and its value is the group's
/// fields in order.
public struct NauticDescriptors: Sendable {
  public static func path(_ entry: UInt32) -> String { "/Logbook/byId/\(entry)/Descriptors" }
  public static func summaryPath(_ entry: UInt32) -> String { "/Logbook/byId/\(entry)/Summary" }

  private struct Field: Sendable {
    let path: String?
    let format: String
    /// What the raw value is divided by, from a `<MOD>x/1000` line: 1 where there is none.
    let divisor: Double
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
      var divisor = 1.0
      for line in text.split(whereSeparator: { $0 == "\n" || $0 == "\0" }) {
        if line.hasPrefix("<PTH>") { path = String(line.dropFirst(5)) }
        if line.hasPrefix("<FRM>") { format = String(line.dropFirst(5)) }
        if line.hasPrefix("<MOD>x/"),
          let by = Double(line.dropFirst(7).prefix { $0 != "," }), by > 0
        {
          divisor = by
        }
        if line.hasPrefix("<GRP>") {
          groups[key] = line.dropFirst(5).split(separator: ",").compactMap { Int($0) }
        }
      }
      if let format { fields[key] = Field(path: path, format: format, divisor: divisor) }
    }
  }

  /// The sport a summary names: the integer at its field whose path ends `Header.ActivityType`,
  /// at the offset the group's fields before it add up to. Nil where no record carries that
  /// field, and where any record does not fit these descriptors — its id names no group, or
  /// its group's fields do not fill its bytes exactly — since then the offset cannot be trusted.
  public func sport(inSummary summary: Data) -> Int? {
    value(at: "Header.ActivityType", inSummary: summary).flatMap { Int(exactly: $0) }
  }

  /// How long the entry lasted, in seconds: the field whose path ends `Header.Duration`, read as
  /// ``sport(inSummary:)`` reads the sport. Nil where it is missing, or zero or less.
  public func duration(inSummary summary: Data) -> TimeInterval? {
    value(at: "Header.Duration", inSummary: summary).flatMap { $0 > 0 ? $0 : nil }
  }

  /// What the summary of entry `id` says of its dive, each read as ``sport(inSummary:)`` reads
  /// the sport and none where it is missing, at its nil value, or zero or less: the start, which
  /// is the id, with the offset `Header.DateTime` logged where its clock less that offset is the
  /// id; the length, `Header.DiveTime`, else `Header.Duration`; the depth, `Header.Depth.Max`.
  public func facts(inSummary summary: Data, id: UInt32) -> ListedDiveFacts {
    func positive(_ path: String) -> Double? {
      value(at: path, inSummary: summary).flatMap { $0 > 0 ? $0 : nil }
    }
    let instant = Date(timeIntervalSince1970: TimeInterval(id))
    return ListedDiveFacts(
      start: .instant(instant, offsetSeconds: loggedOffset(inSummary: summary, at: instant)),
      length: positive("Header.DiveTime") ?? positive("Header.Duration"),
      maxDepth: positive("Header.Depth.Max"))
  }

  /// The offset of `Header.DateTime`, a `local64`: seven little-endian bytes of the wall clock
  /// in milliseconds, then a signed byte of the offset in quarter hours. Nil where its clock
  /// less its offset is not `instant`, which is what stands behind the sign.
  private func loggedOffset(inSummary summary: Data, at instant: Date) -> Int? {
    guard let (field, bytes) = self.field(at: "Header.DateTime", inSummary: summary),
      field.format.hasPrefix("local64"), bytes.count == 8
    else { return nil }
    let value = [UInt8](bytes)
    let wallClock = value.prefix(7).reversed().reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
    let offset = Int(Int8(bitPattern: value[7])) * 15 * 60
    let logged = Double(wallClock) / 1000 - Double(offset)
    return abs(logged - instant.timeIntervalSince1970) < 60 ? offset : nil
  }

  /// The number at the first field whose path is `path` or ends `.` and `path`, scaled by its
  /// `<MOD>`; nil at the format's `nillable` value, and under the same conditions
  /// ``sport(inSummary:)`` gives.
  private func value(at path: String, inSummary summary: Data) -> Double? {
    guard let (field, bytes) = field(at: path, inSummary: summary),
      let raw = Self.number(field.format, bytes)
    else { return nil }
    if let none = Self.nillable(field.format), raw == none { return nil }
    return raw / field.divisor
  }

  /// The field at `path` and its bytes in the summary; nil where no record carries it, or any
  /// record does not fit these descriptors.
  private func field(at path: String, inSummary summary: Data) -> (Field, Data.SubSequence)? {
    guard let records = Self.records(summary) else { return nil }
    var found: (Field, Data.SubSequence)?
    for (id, value) in records {
      guard let group = groups[id] else { return nil }
      var offset = value.startIndex
      for key in group {
        guard let field = fields[key], let size = Self.size(field.format, value[offset...])
        else { return nil }
        guard offset + size <= value.endIndex else { return nil }
        if found == nil, let named = field.path, named == path || named.hasSuffix("." + path) {
          found = (field, value[offset..<(offset + size)])
        }
        offset += size
      }
      guard offset == value.endIndex else { return nil }
    }
    return found
  }

  /// A format's `nillable=` value, which stands for no value.
  private static func nillable(_ format: String) -> Double? {
    format.split(separator: ",").lazy.compactMap { part -> Double? in
      guard part.hasPrefix("nillable=") else { return nil }
      return Double(part.dropFirst("nillable=".count))
    }.first
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

  /// A little-endian number field's value; nil for a format that is no number.
  private static func number(_ format: String, _ bytes: Data.SubSequence) -> Double? {
    let base = format.prefix { $0 != "," }
    let unsigned = bytes.reversed().reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
    let bits = UInt64(bytes.count * 8)
    switch base {
    case "uint8", "uint16", "uint32": return Double(unsigned)
    case "int8", "int16", "int32":
      let sign = UInt64(1) << (bits - 1)
      return Double(unsigned & sign == 0 ? Int64(unsigned) : Int64(unsigned) - Int64(sign << 1))
    case "float32": return Double(Float(bitPattern: UInt32(unsigned)))
    case "float64": return Double(bitPattern: unsigned)
    default: return base.hasPrefix("enum") ? Double(unsigned) : nil
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
