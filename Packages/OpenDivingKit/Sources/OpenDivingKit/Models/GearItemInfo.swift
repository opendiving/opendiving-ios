import Foundation

/// A piece of gear named on a dive, or the cylinder a mixture was breathed from. A gear set
/// lists its items as these, and a dive form holds them, so the item may be one the phone has
/// created and not yet sent.
public struct GearItemInfo: Codable, Hashable, Sendable {
  public var ref: RecordRef
  public var name: String
  public var brand: String?
  /// A gear-type key, read as the string the API sent.
  public var type: String?
  public var rented: Bool
  public var isArchived: Bool
  /// A cylinder's water capacity, in litres.
  public var volume: Double?
  /// A cylinder's rated pressure, in bar.
  public var workingPressure: Double?
  public var material: String?

  enum CodingKeys: String, CodingKey {
    case ref = "uuid"
    case name, brand, type, rented, isArchived, volume, workingPressure, material
  }

  public init(
    ref: RecordRef, name: String, brand: String? = nil, type: String? = nil,
    rented: Bool = false, isArchived: Bool = false, volume: Double? = nil,
    workingPressure: Double? = nil, material: String? = nil
  ) {
    self.ref = ref
    self.name = name
    self.brand = brand
    self.type = type
    self.rented = rented
    self.isArchived = isArchived
    self.volume = volume
    self.workingPressure = workingPressure
    self.material = material
  }
}
