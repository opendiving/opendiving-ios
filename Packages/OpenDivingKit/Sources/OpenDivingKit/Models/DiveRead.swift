import Foundation

/// The fields every dive response carries. Measurements are metric on the wire whatever the
/// account's units: metres, °C, kilograms. Every vocabulary is the string the API sent, so a
/// value this version has no label for still reaches the screen.
public struct DiveRead: Codable, Hashable, Sendable {
  public let uuid: UUID
  public let diveNumber: Int
  /// Any of the four `start_time` spellings, kept as sent.
  public let startTime: DiveTimestamp
  /// Seconds in the water, surface time excluded.
  public let submergedTime: Int
  public let maxDepth: Double?
  public let avgDepth: Double?
  public let bottomTemperature: Double?
  /// Whole metres.
  public let visibility: Int?
  /// Kilograms of ballast.
  public let weight: Double?
  /// `salt`, `fresh` or `brackish`.
  public let waterType: String?
  /// `open_circuit`, `closed_circuit`, `semi_closed`, `freedive`, `snorkel` or
  /// `surface_supplied`.
  public let type: String?
  /// Whole metres above sea level.
  public let altitude: Int?
  /// 1 to 5.
  public let rating: Int?
  public let airTemperature: Double?
  public let current: String?
  public let waves: String?
  public let weather: String?
  /// `shore`, `boat`, `pier` or `pool`.
  public let entryType: String?
  public let boatName: String?
  public let notes: String
  public let entryLatitude: Double?
  public let entryLongitude: Double?
  public let exitLatitude: Double?
  public let exitLongitude: Double?
  public let userUuid: UUID
  public let tripUuid: UUID?
  public let courseUuid: UUID?
  /// The dive centre that ran the dive.
  public let contactUuid: UUID?
  public let createdAt: DiveTimestamp
  /// In the order visited.
  public let diveSites: [DiveSiteInfo]
  public let gearItems: [GearItemInfo]
}
