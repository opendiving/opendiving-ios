import Foundation

/// The zone a position lies in. A protocol because the Kit builds where CoreLocation does not
/// exist: the app target conforms it over Apple's geocoder, and a test over a fake.
@MainActor
public protocol PositionZoneLookup: AnyObject {
  /// The zone at the position, nil where it has none; throws where the question could not be
  /// asked, offline for one, and nothing further is asked of this download.
  func zone(latitude: Double, longitude: Double) async throws -> TimeZone?
}

/// The zones the dives of one download lay in, by fingerprint, for the dives that log an instant
/// and carry a position.
enum DivePositionZones {
  @MainActor
  static func resolve(_ dives: [DownloadedDive], lookup: any PositionZoneLookup) async
    -> [Data: TimeZone]
  {
    var zones: [Data: TimeZone] = [:]
    // A trip revisits its sites, and the geocoder throttles a long walk.
    var answers: [Place: TimeZone?] = [:]
    for downloaded in dives {
      guard let dive = downloaded.dive, case .instant = dive.start,
        let position = dive.entryPosition
      else { continue }
      let place = Place(latitude: position.latitude, longitude: position.longitude)
      if answers[place] == nil {
        do {
          answers[place] = .some(
            try await lookup.zone(latitude: position.latitude, longitude: position.longitude))
        } catch {
          break
        }
      }
      if let zone = answers[place] ?? nil, isCivil(zone) { zones[downloaded.fingerprint] = zone }
    }
    return zones
  }

  /// At sea the geocoder answers `GMT+0200`, a nautical band by longitude that no local clock
  /// keeps: in an Egyptian summer the Red Sea's is an hour off the boat's.
  private static func isCivil(_ zone: TimeZone) -> Bool {
    !zone.identifier.hasPrefix("GMT")
  }

  /// A position to about a kilometre, well inside any one dive site.
  private struct Place: Hashable {
    let latitude: Int
    let longitude: Int

    init(latitude: Double, longitude: Double) {
      self.latitude = Int((latitude * 100).rounded())
      self.longitude = Int((longitude * 100).rounded())
    }
  }
}
