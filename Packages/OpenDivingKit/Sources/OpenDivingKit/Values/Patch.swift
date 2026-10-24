/// One member of a partial update, in the three states a `PATCH` body tells apart: not sent,
/// which leaves the stored value; sent as `null`, which clears it; sent with a value.
///
/// A struct whose member is a `Patch` encodes nothing at all for ``absent`` — the key is left
/// out, not written as null — and decodes a missing key as ``absent``, through the container
/// overloads below, so a body read back from disk is the body that was queued.
public enum Patch<Value: Hashable & Sendable>: Hashable, Sendable {
  case absent
  case null
  case value(Value)

  /// ``absent`` for nil, else ``value(_:)``.
  public init(_ value: Value?) {
    self = value.map(Patch.value) ?? .absent
  }

  /// What the member holds once the update has applied, given what it held before.
  public func applied(to current: Value?) -> Value? {
    switch self {
    case .absent: current
    case .null: nil
    case .value(let value): value
    }
  }
}

extension Patch: Encodable where Value: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    // Reached only when a `Patch` is encoded on its own, outside a keyed container.
    case .absent, .null: try container.encodeNil()
    case .value(let value): try container.encode(value)
    }
  }
}

extension Patch: Decodable where Value: Decodable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    self = container.decodeNil() ? .null : .value(try container.decode(Value.self))
  }
}

extension KeyedEncodingContainer {
  public mutating func encode<Value: Encodable>(_ patch: Patch<Value>, forKey key: Key) throws {
    switch patch {
    case .absent: break
    case .null: try encodeNil(forKey: key)
    case .value(let value): try encode(value, forKey: key)
    }
  }
}

extension KeyedDecodingContainer {
  public func decode<Value: Decodable>(_ type: Patch<Value>.Type, forKey key: Key) throws
    -> Patch<Value>
  {
    guard contains(key) else { return .absent }
    return try decodeNil(forKey: key) ? .null : .value(decode(Value.self, forKey: key))
  }
}

extension Patch where Value == RecordRef {
  /// A dropped ref becomes ``absent``: the update no longer touches the member, rather than
  /// clearing what the server holds.
  mutating func rewrite(_ rewrite: (RecordRef) -> RecordRef?) {
    if case .value(let ref) = self {
      self = rewrite(ref).map(Patch.value) ?? .absent
    }
  }
}
