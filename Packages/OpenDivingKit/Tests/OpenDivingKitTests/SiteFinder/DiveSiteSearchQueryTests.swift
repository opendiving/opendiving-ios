import Foundation
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Every coordinate the finder sends is rounded to two decimals, the view outward.
struct DiveSiteSearchQueryTests {
  private func values(_ query: DiveSiteSearchQuery) -> [String: String] {
    Dictionary(uniqueKeysWithValues: query.items.map { ($0.name, $0.value ?? "") })
  }

  @Test func theCameraIsRoundedToTwoDecimals() {
    let sent = values(
      DiveSiteSearchQuery(
        text: " Canyon ", camera: DeviceLocation(latitude: 28.56873, longitude: -0.4951)))
    #expect(sent["q"] == "Canyon")
    #expect(sent["latitude"] == "28.57")
    #expect(sent["longitude"] == "-0.50")
    #expect(sent["south"] == nil)
    #expect(sent["my"] == nil)
  }

  @Test func aSpeciesNarrowsTheDiversSitesToThoseItWasSeenAt() {
    let species = UUID(uuidString: "6F0C2A52-6F43-4B35-9F1B-2C1D0E3A4B5C")!
    let sent = values(DiveSiteSearchQuery(yours: true, species: species))
    #expect(sent["my"] == "true")
    #expect(sent["species_uuid"] == "6f0c2a52-6f43-4b35-9f1b-2c1d0e3a4b5c")
    #expect(values(DiveSiteSearchQuery(yours: true))["species_uuid"] == nil)
  }

  @Test func theViewIsRoundedOutward() {
    let sent = values(
      DiveSiteSearchQuery(
        camera: DeviceLocation(latitude: 28.5, longitude: 34.5),
        box: LatLonBounds(south: 28.4119, north: 28.6201, west: 34.4011, east: 34.6699)))
    #expect(sent["south"] == "28.41")
    #expect(sent["north"] == "28.63")
    #expect(sent["west"] == "34.40")
    #expect(sent["east"] == "34.67")
  }

  @Test func aViewOverTheAntimeridianIsWrappedWithItsWestPastItsEast() {
    let sent = values(
      DiveSiteSearchQuery(
        camera: DeviceLocation(latitude: -17.7, longitude: 180.2),
        box: LatLonBounds(south: -18.5, north: -16.9, west: 177.3, east: 183.1)))
    #expect(sent["longitude"] == "-179.80")
    #expect(sent["west"] == "177.30")
    #expect(sent["east"] == "-176.90")
  }

  @Test func aViewWiderThanTheWorldIsTheWorld() {
    let sent = values(
      DiveSiteSearchQuery(
        camera: DeviceLocation(latitude: 20, longitude: 0),
        box: LatLonBounds(south: -85.06, north: 85.06, west: -400, east: 410)))
    #expect(sent["west"] == "-180.00")
    #expect(sent["east"] == "180.00")
    #expect(sent["south"] == "-85.06")
  }

  @Test func aViewEndingOnTheLineDoesNotCrossIt() {
    let sent = values(
      DiveSiteSearchQuery(
        camera: DeviceLocation(latitude: 0, longitude: 170),
        box: LatLonBounds(south: -1, north: 1, west: 160, east: 180)))
    #expect(sent["west"] == "160.00")
    #expect(sent["east"] == "180.00")
  }

  @Test func noCameraSendsNoCoordinatesAndYourSitesIsSentAsMy() {
    let sent = values(DiveSiteSearchQuery(yours: true))
    #expect(sent["latitude"] == nil)
    #expect(sent["longitude"] == nil)
    #expect(sent["my"] == "true")
    #expect(sent["yours"] == nil)
    #expect(sent["q"] == nil)
  }
}
