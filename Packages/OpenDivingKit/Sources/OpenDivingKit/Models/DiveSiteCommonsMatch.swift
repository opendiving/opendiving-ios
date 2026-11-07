import Foundation

/// The Commons record a diver's own site shares a registry entry with.
public struct DiveSiteCommonsMatch: Codable, Hashable, Sendable {
  public let uuid: UUID
  public let name: String

  public init(uuid: UUID, name: String) {
    self.uuid = uuid
    self.name = name
  }
}
