import Foundation

/// A record the phone names: one the server holds, or one created on the phone that the server
/// has not named yet.
///
/// A server ref is written as the bare uuid the API wrote, so every response round-trips
/// unchanged, and a local one as `local:<uuid>`. A local ref never reaches the wire: encoded
/// for a request (``APICoding/requestEncoder()``) it throws ``LocalRefOnTheWire``, because the
/// API would refuse the uuid and the create that names the record has to land first.
public enum RecordRef: Hashable, Sendable {
  case server(UUID)
  case local(UUID)

  static let localPrefix = "local:"

  /// The uuid either way: the server's, or the phone's own until the server names it.
  public var uuid: UUID {
    switch self {
    case .server(let uuid), .local(let uuid): uuid
    }
  }

  /// The server's uuid; nil while the record is the phone's alone.
  public var serverUUID: UUID? {
    if case .server(let uuid) = self { uuid } else { nil }
  }

  public var isLocal: Bool {
    if case .local = self { true } else { false }
  }
}

extension RecordRef: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let text = try container.decode(String.self)
    let local = text.hasPrefix(Self.localPrefix)
    guard let uuid = UUID(uuidString: local ? String(text.dropFirst(Self.localPrefix.count)) : text)
    else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Not a record reference: \"\(text)\"")
    }
    self = local ? .local(uuid) : .server(uuid)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .server(let uuid):
      try container.encode(uuid.uuidString.lowercased())
    case .local(let uuid):
      if encoder.userInfo[APICoding.requestKey] as? Bool == true {
        throw LocalRefOnTheWire(ref: self, codingPath: encoder.codingPath)
      }
      try container.encode(Self.localPrefix + uuid.uuidString.lowercased())
    }
  }
}

/// A request body held a record the server has not named yet. The queue rewrites every local
/// ref before it sends, so this is a bug in the caller, never a server's answer.
public struct LocalRefOnTheWire: Error, Hashable, Sendable {
  public let ref: RecordRef
  /// Where in the body it was, by coding key: `diveSiteUuids.0`.
  public let path: String

  init(ref: RecordRef, codingPath: [any CodingKey]) {
    self.ref = ref
    path = codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue }
      .joined(separator: ".")
  }
}
