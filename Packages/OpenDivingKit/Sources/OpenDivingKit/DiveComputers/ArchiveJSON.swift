import Foundation

/// A JSON value the archive writer builds a document from and prints byte for byte the same
/// on every platform: keys sorted, no whitespace, a whole number with no fraction, and every
/// other number in Swift's shortest round-trip spelling. Foundation's serializers are not used
/// because their number spelling is the platform's, and the writer's goldens are compared as
/// bytes on Linux and on the simulator alike.
enum ArchiveJSON: Hashable, Sendable {
  case object([String: ArchiveJSON])
  case array([ArchiveJSON])
  case string(String)
  case integer(Int)
  case number(Double)
  case bool(Bool)

  /// The value as UTF-8 text.
  var text: String {
    var out = ""
    write(into: &out)
    return out
  }

  subscript(key: String) -> ArchiveJSON? {
    if case .object(let members) = self { return members[key] }
    return nil
  }

  var stringValue: String? {
    if case .string(let value) = self { return value }
    return nil
  }

  var integerValue: Int? {
    if case .integer(let value) = self { return value }
    return nil
  }

  var arrayValue: [ArchiveJSON]? {
    if case .array(let items) = self { return items }
    return nil
  }

  /// Parses a document this writer printed; nil for anything that is not JSON.
  static func parse(_ data: Data) -> ArchiveJSON? {
    try? JSONDecoder().decode(ArchiveJSON.self, from: data)
  }

  private func write(into out: inout String) {
    switch self {
    case .object(let members):
      out += "{"
      for (index, key) in members.keys.sorted().enumerated() {
        if index > 0 { out += "," }
        Self.writeString(key, into: &out)
        out += ":"
        members[key]!.write(into: &out)
      }
      out += "}"
    case .array(let items):
      out += "["
      for (index, item) in items.enumerated() {
        if index > 0 { out += "," }
        item.write(into: &out)
      }
      out += "]"
    case .string(let value):
      Self.writeString(value, into: &out)
    case .integer(let value):
      out += String(value)
    case .number(let value):
      out += Self.spell(value)
    case .bool(let value):
      out += value ? "true" : "false"
    }
  }

  /// A finite number as JSON: integral values in range print with no fraction, so that a value
  /// parsed back as an integer prints the same.
  static func spell(_ value: Double) -> String {
    precondition(value.isFinite, "JSON has no spelling for \(value)")
    if value == value.rounded(), abs(value) < 1e15 { return String(Int(value)) }
    return "\(value)"
  }

  private static func writeString(_ value: String, into out: inout String) {
    out += "\""
    for scalar in value.unicodeScalars {
      switch scalar {
      case "\"": out += "\\\""
      case "\\": out += "\\\\"
      case "\n": out += "\\n"
      case "\r": out += "\\r"
      case "\t": out += "\\t"
      case let control where control.value < 0x20:
        let hex = String(control.value, radix: 16)
        out += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
      default:
        out.unicodeScalars.append(scalar)
      }
    }
    out += "\""
  }
}

extension ArchiveJSON: Decodable {
  init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let value = try? container.decode([String: ArchiveJSON].self) {
      self = .object(value)
    } else if let value = try? container.decode([ArchiveJSON].self) {
      self = .array(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Int.self) {
      self = .integer(value)
    } else {
      let value = try container.decode(Double.self)
      self = value == value.rounded() && abs(value) < 1e15 ? .integer(Int(value)) : .number(value)
    }
  }
}
