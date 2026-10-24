import Foundation

/// The JSON spelling of every model: snake_case keys on the wire, camelCase in Swift. Dates
/// are never left to a date strategy — every date and datetime field is a `CalendarDate` or a
/// `DiveTimestamp`, which parse the API's spellings themselves.
public enum APICoding {
  /// Set on ``requestEncoder()`` alone, which is what makes a local ``RecordRef`` throw.
  static let requestKey = CodingUserInfoKey(rawValue: "app.opendiving.request")!

  public static func decoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
  }

  /// For what the phone keeps: a local ``RecordRef`` is written as `local:<uuid>`.
  public static func encoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }

  /// For a request body: as ``encoder()``, except that a local ``RecordRef`` throws
  /// ``LocalRefOnTheWire`` rather than reaching the server.
  public static func requestEncoder() -> JSONEncoder {
    let encoder = encoder()
    encoder.userInfo[requestKey] = true
    return encoder
  }
}
