import Foundation

/// A gear item, as `GET /gear-items` lists it and `POST /gear-item` answers it.
public struct GearItemRead: Codable, Hashable, Sendable, Identifiable {
  public var id: UUID { uuid }

  public let uuid: UUID
  public let name: String
  public let brand: String?
  /// A gear-type key, read as the string the API sent.
  public let type: String?
  public let notes: String
  /// Its manual, its product page and the like, in the diver's order.
  public let links: [WebLink]
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
  /// Its servicing rules, paused ones included.
  public let service: [GearServiceScheduleInfo]
  public let createdAt: DiveTimestamp

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    uuid = try c.decode(UUID.self, forKey: .uuid)
    name = try c.decode(String.self, forKey: .name)
    brand = try c.decodeIfPresent(String.self, forKey: .brand)
    type = try c.decodeIfPresent(String.self, forKey: .type)
    notes = try c.decode(String.self, forKey: .notes)
    links = try c.decodeLinks(forKey: .links)
    rented = try c.decode(Bool.self, forKey: .rented)
    volume = try c.decodeIfPresent(Double.self, forKey: .volume)
    workingPressure = try c.decodeIfPresent(Double.self, forKey: .workingPressure)
    material = try c.decodeIfPresent(String.self, forKey: .material)
    userUuid = try c.decode(UUID.self, forKey: .userUuid)
    isArchived = try c.decode(Bool.self, forKey: .isArchived)
    archivedAt = try c.decodeIfPresent(DiveTimestamp.self, forKey: .archivedAt)
    diveCount = try c.decode(Int.self, forKey: .diveCount)
    diveTime = try c.decode(Int.self, forKey: .diveTime)
    service = try c.decode([GearServiceScheduleInfo].self, forKey: .service)
    createdAt = try c.decode(DiveTimestamp.self, forKey: .createdAt)
  }
}
