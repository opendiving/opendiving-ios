import Foundation
import OpenDivingKit
import Testing

/// A form's trip map fits its places as the web's `LocationsMap` does.
struct MapCameraTests {
  private static let fiji = MapPoint(name: "Fiji", latitude: -17.8, longitude: 178)
  private static let samoa = MapPoint(name: "Samoa", latitude: -13.8, longitude: -172)
  private static let tonga = MapPoint(name: "Tonga", latitude: -21.1, longitude: -175.2)

  /// The degrees of longitude a frame `width` points wide shows at `zoom`.
  private func degreesAcross(_ width: Double, at zoom: Double) -> Double {
    width / (512 * pow(2, zoom)) * 360
  }

  @Test func theWebsNumbers() {
    #expect(MapCamera.placedZoom == 11)
    #expect(MapCamera.maxZoom == 17)
    #expect(MapCamera.minZoom == 0)
    #expect(MapCamera.world == MapCamera(latitude: 20, longitude: 0, zoom: 0))
  }

  @Test func nothingPlacedOrNoFrameIsTheWorld() {
    #expect(MapCamera.fit([], width: 360, height: 200) == .world)
    #expect(MapCamera.fit([Self.fiji], width: 0, height: 0) == .world)
  }

  @Test func aLonePlaceOpensNoDeeperThanAPageHeadsMap() {
    let camera = MapCamera.fit([Self.fiji], width: 360, height: 200)
    #expect(camera.zoom == 9)
    #expect(abs(camera.latitude - Self.fiji.latitude) < 1e-9)
    #expect(abs(camera.longitude - Self.fiji.longitude) < 1e-9)
  }

  @Test func placesAcrossTheAntimeridianFitTheShortWayRound() {
    let camera = MapCamera.fit([Self.fiji, Self.samoa, Self.tonga], width: 360, height: 200)
    #expect(abs(camera.longitude - -177) < 1e-9)
    // Ten degrees apart, which the long way round would make 350.
    #expect(degreesAcross(360 - 48, at: camera.zoom) >= 10)
    #expect(degreesAcross(360 - 48, at: camera.zoom) < 30)
  }

  @Test func aPlaceWithAFootprintFitsTheFootprint() {
    let egypt = MapPoint(
      name: "Egypt", latitude: 26.8, longitude: 30.8,
      bounds: LatLonBounds(south: 22, north: 31.7, west: 24.7, east: 36.9))
    let camera = MapCamera.fit([egypt], width: 360, height: 200)
    #expect(camera.zoom < 5)
    #expect(degreesAcross(360 - 48, at: camera.zoom) >= 36.9 - 24.7)
    #expect(abs(camera.longitude - 30.8) < 1e-9)
  }

  @Test func aFootprintAcrossTheAntimeridianStaysOneInterval() {
    let fiji = MapPoint(
      name: "Fiji", latitude: -17.8, longitude: 178,
      bounds: LatLonBounds(south: -21, north: -12, west: 176, east: -178))
    let camera = MapCamera.fit([fiji], width: 360, height: 200)
    #expect(abs(camera.longitude - 179) < 1e-9)
  }

  @Test func theWholeWorldFitsAtTheShallowestZoom() {
    let world = MapPoint(
      name: "Everywhere", latitude: 0, longitude: 0,
      bounds: LatLonBounds(south: -85, north: 85, west: -180, east: 180))
    #expect(MapCamera.fit([world], width: 360, height: 200).zoom == 0)
  }

  @Test func aFrameNoWiderThanItsPaddingStillAnswers() {
    let camera = MapCamera.fit([Self.fiji], width: 48, height: 48)
    #expect(camera.zoom.isFinite)
  }
}
