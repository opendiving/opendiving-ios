import Foundation
import Observation

/// The photos of a *Aquatic life* tab's species, as each card asks for its own.
@MainActor
@Observable
public final class SpeciesCardPhotos {
  /// Photo bytes by species uuid.
  public private(set) var bytes: [UUID: Data] = [:]

  @ObservationIgnored private let session: Session
  /// The photo version last asked for, by species uuid.
  @ObservationIgnored private var asked: [UUID: String] = [:]

  public init(session: Session) {
    self.session = session
  }

  public subscript(uuid: UUID) -> Data? { bytes[uuid] }

  /// The species' photo, once per version, when it has one. A photo that fails to arrive
  /// leaves the card's no-photo backdrop; one missed for want of a route is asked for again the
  /// next time its card appears.
  public func load(_ entry: SpeciesLifeListEntry) async {
    guard let version = entry.photoSha256, asked[entry.uuid] != version else { return }
    if session.connectivity.isRouteAvailable { asked[entry.uuid] = version }
    if let data = await SpeciesPhotos.photo(entry.uuid, version: version, session: session) {
      asked[entry.uuid] = version
      bytes[entry.uuid] = data
    }
  }
}
