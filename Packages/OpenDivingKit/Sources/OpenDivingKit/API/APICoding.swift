import Foundation

/// The JSON spelling of every model: snake_case keys on the wire, camelCase in Swift. Dates
/// are never left to a date strategy — every date and datetime field is a `CalendarDate` or a
/// `DiveTimestamp`, which parse the API's spellings themselves.
public enum APICoding {
  public static func decoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
  }

  public static func encoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }
}
