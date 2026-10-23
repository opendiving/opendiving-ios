/// One cylinder on a dive. Never sent back: `id` is the API's internal integer, and a write
/// that carries it is refused.
public struct DiveMixtureRead: Codable, Hashable, Sendable {
  public let id: Int
  /// Litres of water capacity.
  public let volume: Double?
  /// Bar.
  public let startPressure: Double?
  public let endPressure: Double?
  /// Percent. Null means not recorded — never read it as 21.
  public let oxygen: Double?
  /// Percent. Null means not recorded — never read it as 0.
  public let helium: Double?
  /// Bar; null falls back to the client's working default.
  public let po2Limit: Double?
  /// The source's label for the cylinder, and the join key to the profile's pressure series.
  public let gasNumber: Int?
  /// What the cylinder was carried for, as the API sent it.
  public let role: String?
  /// How it was breathed, as the API sent it.
  public let usage: String?
  /// The diver's gear item this cylinder is, when linked.
  public let gearItem: GearItemInfo?
}
