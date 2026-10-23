import Foundation
import OpenDivingKit

/// Reads the JSON fixtures under `Fixtures/`.
enum KitFixture {
  static func data(_ name: String) throws -> Data {
    guard
      let url = Bundle.module.url(
        forResource: name, withExtension: "json", subdirectory: "Fixtures")
    else { throw CocoaError(.fileNoSuchFile) }
    return try Data(contentsOf: url)
  }

  static func text(_ name: String) throws -> String {
    String(decoding: try data(name), as: UTF8.self)
  }

  static func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
    try APICoding.decoder().decode(type, from: data(name))
  }

  /// Decodes, encodes and decodes again, so a field the encoder drops or renames shows up as
  /// an inequality.
  static func roundTrip<T: Codable & Equatable>(_ type: T.Type, _ name: String) throws -> T {
    let decoded = try decode(type, name)
    let again = try APICoding.decoder().decode(type, from: APICoding.encoder().encode(decoded))
    guard again == decoded else { throw RoundTripMismatch(fixture: name) }
    return decoded
  }

  struct RoundTripMismatch: Error {
    let fixture: String
  }
}
