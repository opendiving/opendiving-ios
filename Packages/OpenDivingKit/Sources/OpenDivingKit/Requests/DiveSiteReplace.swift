import Foundation

/// `POST /dive-site/{uuid}/replace`'s body.
public struct DiveSiteReplace: Codable, Hashable, Sendable {
  /// The Commons record that takes the site's place.
  public var commonsSite: RecordRef

  enum CodingKeys: String, CodingKey {
    case commonsSite = "commonsSiteUuid"
  }

  public init(commonsSite: UUID) {
    self.commonsSite = .server(commonsSite)
  }
}
