import Foundation
import Testing

@testable import OpenDiving

@MainActor
struct TimeZonePickerTests {
  @Test func aZoneThePhoneKnowsAddsNothing() throws {
    let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
    #expect(TimeZonePicker.identifiers(showing: tokyo) == TimeZone.knownTimeZoneIdentifiers)
  }

  @Test func anOffsetOnlyZoneIsListedSoItsRowIsNotBlank() throws {
    let offset = try #require(TimeZone(secondsFromGMT: 4 * 60 * 60))
    #expect(!TimeZone.knownTimeZoneIdentifiers.contains(offset.identifier))
    #expect(TimeZonePicker.identifiers(showing: offset).first == offset.identifier)
  }
}
