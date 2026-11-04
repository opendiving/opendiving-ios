import OpenDivingKit
import Testing

/// The rule the web's `MapPicker` keeps between the map and the form's position.
struct PinCameraTests {
  private static let dahab = DeviceLocation(latitude: 28.5722, longitude: 34.5372)
  private static let bali = DeviceLocation(latitude: -8.34, longitude: 115.09)

  private func zoomed(_ camera: inout PinCamera, to zoom: Double) {
    var moved = camera.camera
    moved.zoom = zoom
    camera.moved(to: moved)
  }

  @Test func aFormWithNoPositionOpensOnTheWorld() {
    #expect(PinCamera(position: nil).camera == .world)
  }

  @Test func aFormWithAPositionOpensThereAtThePlacedZoom() {
    #expect(
      PinCamera(position: Self.dahab).camera
        == MapCamera(latitude: 28.5722, longitude: 34.5372, zoom: 11))
  }

  @Test func aPickLeavesTheCameraWhereItIs() {
    var camera = PinCamera(position: nil)
    zoomed(&camera, to: 6)
    let before = camera.camera
    camera.picked(Self.dahab)
    camera.follow(Self.dahab)
    #expect(camera.camera == before)
  }

  @Test func aPositionFromElsewhereKeepsTheZoomOnceOneWasHeld() {
    var camera = PinCamera(position: Self.dahab)
    zoomed(&camera, to: 6)
    camera.follow(Self.bali)
    #expect(camera.camera == MapCamera(latitude: -8.34, longitude: 115.09, zoom: 6))
  }

  @Test func theFirstPositionRaisesTheZoomAndNeverLowersIt() {
    var shallow = PinCamera(position: nil)
    shallow.follow(Self.dahab)
    #expect(shallow.camera.zoom == 11)
    #expect(shallow.camera.latitude == 28.5722)

    var deep = PinCamera(position: nil)
    zoomed(&deep, to: 14)
    deep.follow(Self.dahab)
    #expect(deep.camera.zoom == 14)
  }

  @Test func aFirstPickLatchesSoTheNextPositionIsNotAFirst() {
    var camera = PinCamera(position: nil)
    camera.picked(Self.dahab)
    camera.follow(Self.dahab)
    camera.follow(Self.bali)
    #expect(camera.camera.zoom == 0)
    #expect(camera.camera.latitude == -8.34)
  }

  @Test func halfTypedTextDoesNotMakeTheNextKeystrokeAFirstPosition() {
    var camera = PinCamera(position: nil)
    camera.follow(Self.dahab)
    zoomed(&camera, to: 6)
    camera.follow(nil)
    camera.follow(Self.bali)
    #expect(camera.camera.zoom == 6)
  }

  @Test func aClearedPositionLeavesTheCameraWhereItIs() {
    var camera = PinCamera(position: Self.dahab)
    let before = camera.camera
    camera.follow(nil)
    #expect(camera.camera == before)
  }

  @Test func aPickIsSpentOnItsFirstMatch() {
    var camera = PinCamera(position: nil)
    camera.picked(Self.dahab)
    camera.follow(Self.dahab)
    camera.follow(Self.bali)
    // Typed back much later, the first position is somebody else's and the camera follows.
    camera.follow(Self.dahab)
    #expect(camera.camera.latitude == 28.5722)
  }

  @Test func aPickOfThePositionHeldArmsNothing() {
    var camera = PinCamera(position: Self.dahab)
    camera.picked(Self.dahab)
    camera.follow(Self.bali)
    camera.follow(Self.dahab)
    #expect(camera.camera.latitude == 28.5722)
  }

  @Test func aPickStaysArmedThroughAnotherPosition() {
    var camera = PinCamera(position: Self.dahab)
    let pick = DeviceLocation(latitude: 1, longitude: 2)
    camera.picked(pick)
    camera.follow(Self.bali)
    let before = camera.camera
    camera.follow(pick)
    #expect(camera.camera == before)
  }

  @Test func theSamePositionAgainMovesNothing() {
    var camera = PinCamera(position: Self.dahab)
    zoomed(&camera, to: 6)
    var panned = camera.camera
    panned.longitude = 40
    camera.moved(to: panned)
    camera.follow(Self.dahab)
    #expect(camera.camera == panned)
  }

  @Test func aPositionFromTheMapIsFoldedForTheForm() {
    #expect(
      PinCamera.folded(latitude: 89, longitude: 190)
        == DeviceLocation(latitude: 85.0511287798066, longitude: -170))
    #expect(PinCamera.folded(latitude: -89, longitude: 180).longitude == -180)
    #expect(PinCamera.folded(latitude: -89, longitude: 180).latitude == -85.0511287798066)
    #expect(PinCamera.folded(latitude: 10, longitude: -180).longitude == -180)
    let folded = PinCamera.folded(latitude: 10, longitude: 179.5)
    #expect(
      PlaceSearch.position(
        latitude: PlaceSearch.coordinateText(folded.latitude),
        longitude: PlaceSearch.coordinateText(folded.longitude)) == folded)
  }
}
