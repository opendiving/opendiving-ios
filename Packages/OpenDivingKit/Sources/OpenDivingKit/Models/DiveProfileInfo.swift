import Foundation

/// A recording's profile summarised: which curves a chart would draw, their extremes in
/// metres, °C and bar, and the heart rate's maximum and average in whole beats per minute.
public struct DiveProfileInfo: Codable, Hashable, Sendable {
  public let uuid: UUID
  /// Milliseconds.
  public let duration: Int
  public let depthSampleCount: Int
  /// `file`, `divejson_import` or `merge`.
  public let provenance: String
  /// The channel keys present, as the API sent them.
  public let channels: [String]
  public let eventCount: Int?
  public let maxDepth: Double?
  public let maxCeiling: Double?
  public let minTemperature: Double?
  public let maxTemperature: Double?
  public let minPressure: Double?
  public let maxPressure: Double?
  public let maxHeartRate: Int?
  /// Taken by the API over every reading the file carried, which the capped series the chart
  /// draws cannot reproduce.
  public let averageHeartRate: Int?
  public let updatedAt: DiveTimestamp?
}
