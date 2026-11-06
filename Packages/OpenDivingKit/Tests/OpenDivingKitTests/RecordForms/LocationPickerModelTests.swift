import Foundation
import Testing

@testable import OpenDivingKit

/// The full-screen picker: what places the pin, what names it, and what the form is handed.
@MainActor
struct LocationPickerModelTests {
  private static let osm = "[OSM](https://osm.org/copyright)"

  private final class FakeLocator: LocationProvider {
    var outcome: Result<DeviceLocation, LocationFailure>

    init(_ outcome: Result<DeviceLocation, LocationFailure>) {
      self.outcome = outcome
    }

    func currentLocation() async throws(LocationFailure) -> DeviceLocation {
      try outcome.get()
    }
  }

  private func result(_ location: String, bounds: Bool = false) -> GeocodeResult {
    GeocodeResult(
      latitude: 28.5, longitude: 34.5, location: location, name: nil, attribution: Self.osm,
      country: nil, region: nil, source: nil, sourceId: nil, bboxSouth: bounds ? 22 : nil,
      bboxNorth: bounds ? 31 : nil, bboxWest: bounds ? 25 : nil, bboxEast: bounds ? 36 : nil)
  }

  private func commons() -> DiveSiteLookupItem {
    DiveSiteLookupItem(
      ref: .server(UUID(uuidString: "01a14b2e-0c3d-7a10-9f00-4b2b3c4d5e6f")!), name: "Blue Hole",
      otherNames: [], latitude: 28.5722, longitude: 34.5372, location: nil, externalIds: [],
      owner: DiveSiteOwner.commons, saved: false, attribution: Self.osm)
  }

  private func model(
    initial: PickedLocation = PickedLocation(), needsPlace: Bool = false,
    locator: FakeLocator = FakeLocator(.failure(.unavailable)),
    reverse: @escaping PositionLookup.Reverse = { _, _ in .unknown }
  ) -> LocationPickerModel {
    LocationPickerModel(
      search: PlaceSearchModel(text: .diveSitePlace, commons: nil, geocode: { _ in [] }),
      initial: initial, needsPlace: needsPlace, locator: locator, reverse: reverse)
  }

  @Test func aPastedPairPlacesThePinAndNamesIt() async {
    var asked: [Double] = []
    let picker = model(reverse: { latitude, longitude in
      asked = [latitude, longitude]
      return .named(self.result("Dahab, Egypt"))
    })
    picker.query = "27.8506, 34.3136"
    #expect(await picker.queryChanged(from: "", to: picker.query))
    #expect(asked == [27.8506, 34.3136])
    #expect(picker.picked.latitude == "27.8506")
    #expect(picker.picked.longitude == "34.3136")
    #expect(picker.placeName == "Dahab, Egypt")
    #expect(picker.query.isEmpty)
    #expect(picker.camera.latitude == 27.8506)
    #expect(picker.camera.zoom == MapCamera.placedZoom)
    #expect(picker.used.credit == Self.osm)
  }

  @Test func onlyAPasteOrTheSearchKeyReadsCoordinates() async {
    let picker = model()
    picker.query = "27.8 3"
    #expect(await !picker.queryChanged(from: "27.8 ", to: picker.query))
    #expect(picker.position == nil)
    #expect(picker.query == "27.8 3")

    #expect(await picker.submit())
    #expect(picker.position == DeviceLocation(latitude: 27.8, longitude: 3))
  }

  @Test func aPairOutOfRangeIsLeftToTheSearch() async {
    let picker = model()
    picker.query = "95, 34"
    #expect(await !picker.queryChanged(from: "", to: picker.query))
    #expect(picker.position == nil)
    #expect(picker.query == "95, 34")
  }

  @Test func aTapLeavesTheCameraAndFoldsThePosition() async {
    let picker = model(
      initial: PickedLocation(latitude: "28", longitude: "34"),
      reverse: { _, _ in .named(self.result("Dahab")) })
    let camera = picker.camera
    await picker.tapped(latitude: 28.123456789, longitude: 214)
    #expect(picker.picked.latitude == "28.123457")
    #expect(picker.picked.longitude == "-146")
    #expect(picker.camera == camera)
  }

  @Test func aSearchPickBringsItsWholePlaceAndFitsItsFootprint() {
    let picker = model()
    picker.viewport = (width: 390, height: 700)
    picker.query = "egypt"
    picker.pick(.geocode(result("Egypt", bounds: true)))
    #expect(picker.picked.location?.bboxNorth == 31)
    #expect(picker.picked.latitude == "28.5")
    #expect(picker.query.isEmpty)
    #expect(picker.camera.zoom < MapCamera.placedZoom)
    #expect(picker.used.credit == Self.osm)
    #expect(picker.canUse)
  }

  @Test func aSearchPickOutrunsTheLookupStillOut() async {
    var isOut = false
    let picker = model(reverse: { _, _ in
      isOut = true
      try await Task.sleep(for: .milliseconds(20))
      return .named(self.result("Somewhere else"))
    })
    async let tapped: Void = picker.tapped(latitude: 1, longitude: 2)
    while !isOut { await Task.yield() }
    picker.pick(.geocode(result("Dahab")))
    await tapped
    #expect(picker.placeName == "Dahab")
    #expect(!picker.isNaming)
  }

  @Test func myLocationPlacesThePin() async {
    let picker = model(
      locator: FakeLocator(.success(DeviceLocation(latitude: 28.1234567, longitude: 34.5))),
      reverse: { _, _ in .named(self.result("Dahab")) })
    await picker.useMyLocation()
    #expect(picker.picked.latitude == "28.123457")
    #expect(picker.placeName == "Dahab")
    #expect(picker.camera.zoom == MapCamera.placedZoom)
    #expect(!picker.isLocating)
  }

  @Test func aRefusedLocationSaysSoAndMovesNothing() async {
    let picker = model(locator: FakeLocator(.failure(.denied)))
    await picker.useMyLocation()
    #expect(picker.failure == .denied)
    #expect(picker.position == nil)
    #expect(!picker.isLocating)
  }

  @Test func aSiteKeepsAPinNothingNamed() async {
    let picker = model(reverse: { _, _ in .nameless })
    await picker.tapped(latitude: 1, longitude: 2)
    #expect(picker.canUse)
    #expect(picker.used.location == nil)
    #expect(picker.unnamedMessage == nil)
  }

  @Test func aSiteKeepsItsPlaceWhereNothingWasLearned() async {
    let picker = model(
      initial: PickedLocation(
        latitude: "28", longitude: "34", location: LocationWrite(name: "Dahab")))
    await picker.tapped(latitude: 1, longitude: 2)
    #expect(picker.used.location == LocationWrite(name: "Dahab"))
  }

  @Test func aTripPartCannotUseAPinNothingNamed() async {
    let held = LocationWrite(name: "Dahab", latitude: 28, longitude: 34)
    let picker = model(initial: PickedLocation(place: held), needsPlace: true)
    #expect(picker.canUse)
    await picker.tapped(latitude: 1, longitude: 2)
    #expect(!picker.canUse)
    #expect(picker.placeName == nil)
    #expect(picker.unnamedMessage != nil)
  }

  @Test func aTripPartsLookedUpNameGoesWhereThePinIs() async {
    let picker = model(needsPlace: true, reverse: { _, _ in .named(self.result("Dahab")) })
    await picker.tapped(latitude: 1.5, longitude: 2.5)
    #expect(picker.canUse)
    #expect(picker.used.location == LocationWrite(name: "Dahab", latitude: 1.5, longitude: 2.5))
  }

  @Test func aCommonsPickOffersTheRecordUntilThePinMoves() async {
    let picker = model(reverse: { _, _ in .named(self.result("Dahab")) })
    picker.pick(.commons(commons()))
    #expect(picker.offered?.name == "Blue Hole")
    #expect(picker.pin?.latitude == 28.5722)
    #expect(picker.position == nil)
    #expect(!picker.canUse)

    await picker.tapped(latitude: 1, longitude: 2)
    #expect(picker.offered == nil)
    #expect(picker.canUse)
  }

  @Test func opensOnAPositionWithNoPlaceByAskingWhatIsThere() async {
    let picker = model(
      initial: PickedLocation(latitude: "28", longitude: "34"),
      reverse: { _, _ in .named(self.result("Dahab")) })
    await picker.start()
    #expect(picker.placeName == "Dahab")
  }

  @Test func opensOnANamedPositionAskingNothing() async {
    var asked = false
    let picker = model(
      initial: PickedLocation(
        latitude: "28", longitude: "34", location: LocationWrite(name: "Dahab")),
      reverse: { _, _ in
        asked = true
        return .unknown
      })
    await picker.start()
    #expect(!asked)
    #expect(picker.query.isEmpty)
  }

  @Test func opensOnANameWithNoPositionBySearchingForIt() {
    let picker = model(initial: PickedLocation(location: LocationWrite(name: "Dahab")))
    #expect(picker.query == "Dahab")
  }

  @Test func removingWhatTheFormHeldLeavesNoLocationToUse() {
    let picker = model(
      initial: PickedLocation(
        latitude: "28", longitude: "34", location: LocationWrite(name: "Dahab")))
    picker.clear()
    #expect(picker.pin == nil)
    #expect(picker.placeName == nil)
    #expect(picker.isEmpty)
    #expect(picker.canUse)
    #expect(picker.used == PickedLocation())
  }

  @Test func removingAFreshPickGoesBackToNoLocation() {
    let picker = model()
    #expect(picker.isEmpty)
    picker.pick(.geocode(result("Dahab")))
    #expect(!picker.isEmpty)
    picker.clear()
    #expect(picker.pin == nil)
    #expect(picker.isEmpty)
    #expect(picker.used == PickedLocation())
  }

  @Test func anOfferOrAPinBeingNamedIsNotNoLocation() async {
    let picker = model()
    picker.pick(.commons(commons()))
    #expect(!picker.isEmpty)
    #expect(!picker.canUse)

    var isOut = false
    let naming = model(reverse: { _, _ in
      isOut = true
      try await Task.sleep(for: .milliseconds(20))
      return .unknown
    })
    async let tapped: Void = naming.tapped(latitude: 1, longitude: 2)
    while !isOut { await Task.yield() }
    #expect(!naming.isEmpty)
    await tapped
  }

  @Test func aTripPartCanHaveItsPlaceRemoved() {
    let held = LocationWrite(name: "Dahab", latitude: 28, longitude: 34)
    let picker = model(initial: PickedLocation(place: held), needsPlace: true)
    picker.clear()
    #expect(picker.canUse)
    #expect(picker.used.location == nil)
  }

  @Test func removingOutrunsTheLookupStillOut() async {
    var isOut = false
    let picker = model(reverse: { _, _ in
      isOut = true
      try await Task.sleep(for: .milliseconds(20))
      return .named(self.result("Somewhere"))
    })
    async let tapped: Void = picker.tapped(latitude: 1, longitude: 2)
    while !isOut { await Task.yield() }
    picker.clear()
    await tapped
    #expect(picker.pin == nil)
    #expect(picker.placeName == nil)
    #expect(!picker.isNaming)
  }

  @Test func dismissingAnOfferGoesBackToThePin() async {
    let picker = model(reverse: { _, _ in .named(self.result("Dahab")) })
    await picker.tapped(latitude: 1, longitude: 2)
    picker.pick(.commons(commons()))
    picker.clear()
    #expect(picker.offered == nil)
    #expect(picker.placeName == "Dahab")
    #expect(picker.canUse)
  }

  @Test func centeringMovesTheCameraAndNothingElse() {
    let held = PickedLocation(
      latitude: "28", longitude: "34", location: LocationWrite(name: "Dahab"))
    let picker = model(initial: held)
    picker.moved(to: MapCamera(latitude: 1, longitude: 2, zoom: 5))
    picker.centerOnPin()
    #expect(picker.camera == MapCamera(latitude: 28, longitude: 34, zoom: 5))
    #expect(picker.picked == held)
  }

  @Test func centeringFollowsAnOfferAndHasNothingToDoWithNoPin() {
    let picker = model()
    let camera = picker.camera
    picker.centerOnPin()
    #expect(picker.camera == camera)

    picker.pick(.commons(commons()))
    picker.moved(to: MapCamera(latitude: 1, longitude: 2, zoom: 5))
    picker.centerOnPin()
    #expect(picker.camera.latitude == 28.5722)
  }

  @Test func aPartsPlaceOpensWhereItSaysItIs() {
    let picked = PickedLocation(place: LocationWrite(name: "Dahab", latitude: 28.5, longitude: 34))
    #expect(picked.latitude == "28.5")
    #expect(picked.longitude == "34")
    #expect(PickedLocation(place: nil) == PickedLocation())
  }
}
