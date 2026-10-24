import Foundation

/// One cylinder of a dive being written, `DiveMixtureCreate`. Carries no `id`: a write
/// replaces a dive's cylinders wholesale, and a body naming one is refused.
public struct DiveMixtureWrite: Codable, Hashable, Sendable {
  /// Litres of water capacity.
  public var volume: Double?
  /// Bar, above 0 and at most 350.
  public var startPressure: Double?
  /// Bar, 0 to 350.
  public var endPressure: Double?
  /// Percent.
  public var oxygen: Double?
  /// Percent.
  public var helium: Double?
  /// Bar, 0.4 to 2.0.
  public var po2Limit: Double?
  public var gasNumber: Int?
  public var role: String?
  public var usage: String?
  /// The diver's cylinder this is, when linked.
  public var gearItem: RecordRef?

  enum CodingKeys: String, CodingKey {
    case volume, startPressure, endPressure, oxygen, helium, po2Limit, gasNumber, role, usage
    case gearItem = "gearItemUuid"
  }

  public init(
    volume: Double? = nil, startPressure: Double? = nil, endPressure: Double? = nil,
    oxygen: Double? = nil, helium: Double? = nil, po2Limit: Double? = nil,
    gasNumber: Int? = nil, role: String? = nil, usage: String? = nil, gearItem: RecordRef? = nil
  ) {
    self.volume = volume
    self.startPressure = startPressure
    self.endPressure = endPressure
    self.oxygen = oxygen
    self.helium = helium
    self.po2Limit = po2Limit
    self.gasNumber = gasNumber
    self.role = role
    self.usage = usage
    self.gearItem = gearItem
  }
}

extension DiveMixtureWrite: RewritesLocalRefs {
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    gearItem.rewrite(rewrite)
  }
}
