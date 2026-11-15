import Foundation

/// A site a dive visited, with enough of it to place on a map.
public struct DiveSiteInfo: Codable, Hashable, Sendable {
  public var ref: RecordRef
  public var name: String
  /// The locality around the site; its coordinates are the locality's centre, not the pin.
  public var location: LocationRead?
  public var latitude: Double?
  public var longitude: Double?
  /// ``DiveSiteOwner``'s. Absent from a copy stored before the server sent it, and from a site a
  /// pending edit names.
  public var owner: String?
  /// The diver's latest proposal of the site, while it waits or once declined.
  public var proposalStatus: String?

  enum CodingKeys: String, CodingKey {
    case ref = "uuid"
    case name, location, latitude, longitude, owner, proposalStatus
  }

  /// Nil where the owner is not known.
  public var mark: DiveSiteMark? {
    owner.map { DiveSiteMark(owner: $0, proposalStatus: proposalStatus) }
  }

  public init(
    ref: RecordRef, name: String, location: LocationRead? = nil, latitude: Double? = nil,
    longitude: Double? = nil, owner: String? = nil, proposalStatus: String? = nil
  ) {
    self.ref = ref
    self.name = name
    self.location = location
    self.latitude = latitude
    self.longitude = longitude
    self.owner = owner
    self.proposalStatus = proposalStatus
  }
}
