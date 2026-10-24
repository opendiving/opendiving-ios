import Foundation

/// Any JSON, compared by value: two bodies are equal when they hold the same keys with the
/// same values, whatever the order or the spelling of a number.
enum JSONValue: Decodable, Equatable, CustomStringConvertible {
  case null
  case bool(Bool)
  case number(Double)
  case string(String)
  case array([JSONValue])
  case object([String: JSONValue])

  init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Double.self) {
      // Before `Bool`, which a decoder may read a 0 or a 1 as.
      self = .number(value)
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([JSONValue].self) {
      self = .array(value)
    } else {
      self = .object(try container.decode([String: JSONValue].self))
    }
  }

  static func parse(_ data: Data) throws -> JSONValue {
    try JSONDecoder().decode(JSONValue.self, from: data)
  }

  /// The keys of an object.
  var keys: Set<String> {
    if case .object(let members) = self { Set(members.keys) } else { [] }
  }

  subscript(key: String) -> JSONValue? {
    if case .object(let members) = self { members[key] } else { nil }
  }

  var description: String {
    switch self {
    case .null: "null"
    case .bool(let value): String(value)
    case .number(let value): String(value)
    case .string(let value): "\"\(value)\""
    case .array(let values): "[" + values.map(\.description).joined(separator: ",") + "]"
    case .object(let members):
      "{"
        + members.sorted { $0.key < $1.key }.map { "\"\($0.key)\":\($0.value)" }
        .joined(separator: ",") + "}"
    }
  }
}
