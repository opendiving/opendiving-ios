import Foundation
import Testing

@testable import OpenDivingKit

@MainActor
struct DivePositionZonesTests {
  private typealias F = DiveComputerFixtures

  private let cairo = TimeZone(identifier: "Africa/Cairo")!

  /// An Ocean dive at a position, or with none.
  private func dive(_ id: UInt8, at position: String? = nil) -> DownloadedDive {
    let entry = position.map { #""entry_position":\#($0),"# } ?? ""
    let json =
      #"{\#(entry)"recordings":[{}],"started_at":"2026-10-24T10:00:00+00:00","#
      + #""submerged_time":3000}"#
    let dive = ComputerDive(json: Data(json.utf8), logsInstants: true, fallbackStart: nil)!
    return DownloadedDive(
      identity: F.ocean, fingerprint: Data([id]), bytes: Data(), reading: .dive(dive))
  }

  private let dahab = #"{"latitude":28.5,"longitude":34.52}"#
  private let nearby = #"{"latitude":28.501,"longitude":34.521}"#
  private let bali = #"{"latitude":-8.27,"longitude":115}"#

  @Test func aDiveWithAPositionTakesItsZoneAndOneWithoutIsLeftOut() async {
    let zones = await DivePositionZones.resolve(
      [dive(1, at: dahab), dive(2)], lookup: FakePositionZones(cairo))
    #expect(zones == [Data([1]): cairo])
  }

  @Test func theSameSiteIsAskedOnce() async {
    let lookup = FakePositionZones(cairo)
    let zones = await DivePositionZones.resolve(
      [dive(1, at: dahab), dive(2, at: nearby), dive(3, at: bali)], lookup: lookup)
    #expect(lookup.asked == 2)
    #expect(zones.count == 3)
  }

  @Test func aNauticalBandIsNoZone() async {
    for name in ["GMT+0200", "GMT-0900", "GMT"] {
      let zones = await DivePositionZones.resolve(
        [dive(1, at: dahab)], lookup: FakePositionZones(TimeZone(identifier: name)))
      #expect(zones.isEmpty, "\(name)")
    }
  }

  @Test func aFailedLookupStopsTheAskingAndKeepsWhatItHas() async {
    let lookup = FakePositionZones(cairo, failsAfter: 1)
    let far = #"{"latitude":40,"longitude":10}"#
    let zones = await DivePositionZones.resolve(
      [dive(1, at: dahab), dive(2, at: bali), dive(3, at: far)], lookup: lookup)
    #expect(zones == [Data([1]): cairo])
    #expect(lookup.asked == 2)
  }

  @Test func aWallClockIsNotLookedUp() async {
    let lookup = FakePositionZones(cairo)
    let json =
      #"{"entry_position":{"latitude":1,"longitude":2},"recordings":[{}],"#
      + #""started_at":"2026-10-24T10:00:00","submerged_time":3000}"#
    let wallClock = ComputerDive(json: Data(json.utf8), logsInstants: false, fallbackStart: nil)!
    let downloaded = DownloadedDive(
      identity: F.perdix, fingerprint: Data([1]), bytes: Data(), reading: .dive(wallClock))
    let zones = await DivePositionZones.resolve([downloaded], lookup: lookup)
    #expect(zones.isEmpty)
    #expect(lookup.asked == 0)
  }
}
