import Foundation

/// A gear set, a row of `GET /gear-sets`: the items a diver takes together, in order, and the
/// ballast that goes with them.
public struct GearSetRead: Codable, Hashable, Sendable {
  public let uuid: UUID
  public let name: String
  /// Kilograms.
  public let weight: Double?
  public let userUuid: UUID
  public let createdAt: DiveTimestamp
  /// In the set's order, archived ones included.
  public let gearItems: [GearItemInfo]
}
