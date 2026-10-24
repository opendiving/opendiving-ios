import Foundation

/// A gear item as `POST /gear-item` answers it.
public struct GearItemRead: Codable, Hashable, Sendable {
  public let uuid: UUID
  public let name: String
  public let brand: String?
  /// A gear-type key, read as the string the API sent.
  public let type: String?
  public let notes: String
  public let rented: Bool
  public let volume: Double?
  public let workingPressure: Double?
  public let material: String?
  public let userUuid: UUID
  public let isArchived: Bool
  public let archivedAt: DiveTimestamp?
  /// The owner's dives it was used on.
  public let diveCount: Int
  /// Seconds in the water on those dives.
  public let diveTime: Int
  public let createdAt: DiveTimestamp
}
