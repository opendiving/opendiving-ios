import Foundation

@testable import OpenDivingKit

/// A ``PositionZoneLookup`` that answers `zone` for every position, and throws after `failsAfter`
/// answers, counting what it was asked.
@MainActor
final class FakePositionZones: PositionZoneLookup {
  struct Offline: Error {}

  var zone: TimeZone?
  var failsAfter: Int?
  private(set) var asked = 0

  init(_ zone: TimeZone? = nil, failsAfter: Int? = nil) {
    self.zone = zone
    self.failsAfter = failsAfter
  }

  func zone(latitude: Double, longitude: Double) async throws -> TimeZone? {
    defer { asked += 1 }
    if let failsAfter, asked >= failsAfter { throw Offline() }
    return zone
  }
}
