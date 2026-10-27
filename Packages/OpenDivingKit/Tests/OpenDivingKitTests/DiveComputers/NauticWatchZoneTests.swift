import Foundation
import Testing

@testable import OpenDivingKit

/// The decode over the resources captured from a Suunto Ocean set to Cairo, UTC+3 with daylight
/// saving on.
struct NauticWatchZoneTests {
  private func captured(_ name: String) throws -> Data {
    let url = try #require(
      Bundle.module.url(
        forResource: name, withExtension: "bin", subdirectory: "Fixtures/DiveComputers/ocean-zone"
      ))
    return try Data(contentsOf: url)
  }

  private func resources() throws -> [String: Data] {
    [
      NauticWatchZone.zoneInfoPath: try captured("time-zone-info"),
      NauticWatchZone.offsetPath: try captured("local-time-offset"),
    ]
  }

  @Test func theWatchsZoneIsItsIdentifier() throws {
    let zone = try #require(NauticWatchZone.decode(try resources()))
    #expect(zone.identifier == "Africa/Cairo")
  }

  @Test func withoutTheIdentifierTheOffsetIsTheZone() throws {
    var resources = try resources()
    resources[NauticWatchZone.zoneInfoPath] = nil
    #expect(NauticWatchZone.decode(resources) == TimeZone(secondsFromGMT: 3 * 3600))
  }

  @Test func anIdentifierNoZoneNamesFallsBackToTheOffset() throws {
    var resources = try resources()
    var info = try captured("time-zone-info")
    let name = try #require(info.firstRange(of: Data("Africa/Cairo".utf8)))
    info.replaceSubrange(name, with: Data("Nowhere/Here".utf8))
    resources[NauticWatchZone.zoneInfoPath] = info
    #expect(NauticWatchZone.decode(resources) == TimeZone(secondsFromGMT: 3 * 3600))
  }

  @Test func theOffsetIsSignedMinutes() throws {
    var offset = [UInt8](try captured("local-time-offset"))
    // Minutes east of UTC, as an Int16: -150 is UTC-2:30.
    offset[12] = UInt8(truncatingIfNeeded: -150)
    offset[13] = UInt8(truncatingIfNeeded: -150 >> 8)
    let zone = NauticWatchZone.decode([NauticWatchZone.offsetPath: Data(offset)])
    #expect(zone == TimeZone(secondsFromGMT: -150 * 60))
  }

  @Test func nothingReadableIsNoZone() throws {
    #expect(NauticWatchZone.decode([:]) == nil)
    #expect(NauticWatchZone.decode([NauticWatchZone.offsetPath: Data([0x01, 0x02])]) == nil)
    var offset = [UInt8](try captured("local-time-offset"))
    offset[10] = 0x10  // a structure, not an integer
    #expect(NauticWatchZone.decode([NauticWatchZone.offsetPath: Data(offset)]) == nil)
  }
}
