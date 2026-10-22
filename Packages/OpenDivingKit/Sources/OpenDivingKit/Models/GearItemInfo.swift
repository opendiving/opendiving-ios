import Foundation

/// A piece of gear named on a dive, or the cylinder a mixture was breathed from.
public struct GearItemInfo: Codable, Hashable, Sendable {
  public let uuid: UUID
  public let name: String
  public let brand: String?
  /// A gear-type key, read as the string the API sent.
  public let type: String?
  public let rented: Bool
  public let isArchived: Bool
  /// A cylinder's water capacity, in litres.
  public let volume: Double?
  /// A cylinder's rated pressure, in bar.
  public let workingPressure: Double?
  public let material: String?
}
