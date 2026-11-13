import Foundation
import OpenDivingKit
import Testing

/// A tap on a group of sites opens it onto the sites it gathers.
struct SiteFinderGroupCameraTests {
  private static func site(_ latitude: Double, _ longitude: Double) -> MapPoint {
    MapPoint(name: "", latitude: latitude, longitude: longitude)
  }

  /// The degrees of longitude a frame `width` points wide shows at `zoom`.
  private func degreesAcross(_ width: Double, at zoom: Double) -> Double {
    width / (512 * pow(2, zoom)) * 360
  }

  @Test func noSitesIsNoCamera() {
    #expect(
      MapCamera.group([], splitting: 5, width: 390, height: 400, padding: MapPadding(32)) == nil)
  }

  @Test func theSitesFitInsideThePadding() {
    // Dahab's reefs, a dozen kilometres of coast.
    let sites = [Self.site(28.57, 34.54), Self.site(28.49, 34.51), Self.site(28.42, 34.45)]
    let camera = MapCamera.group(
      sites, splitting: 9, width: 390, height: 400, padding: MapPadding(32))!
    #expect(camera.zoom > 10)
    #expect(degreesAcross(390 - 64, at: camera.zoom) >= 34.54 - 34.45)
    #expect(abs(camera.longitude - (34.54 + 34.45) / 2) < 1e-9)
    let shown = camera.bounds(width: 390 - 64, height: 400 - 64)
    // The edge the fit is made on lands on its site, give or take the arithmetic.
    #expect(shown.south <= 28.42 + 1e-9 && shown.north >= 28.57 - 1e-9)
    // A fit, not a margin: half a zoom deeper and the sites no longer fit.
    let deeper = MapCamera(
      latitude: camera.latitude, longitude: camera.longitude, zoom: camera.zoom + 0.5
    )
    .bounds(width: 390 - 64, height: 400 - 64)
    #expect(
      deeper.south > 28.42 || deeper.north < 28.57 || deeper.west > 34.45 || deeper.east < 34.54)
  }

  @Test func unevenPaddingCentresTheSitesInWhatItLeaves() {
    let sites = [Self.site(28.57, 34.54), Self.site(28.42, 34.45)]
    let padding = MapPadding(top: 80, left: 80, bottom: 40, right: 80)
    let camera = MapCamera.group(sites, splitting: 9, width: 390, height: 400, padding: padding)!
    let even = MapCamera.group(
      sites, splitting: 9, width: 230, height: 280, padding: MapPadding(0))!
    // The same inner frame fits the same zoom, its middle 20 points under the camera's.
    #expect(abs(camera.zoom - even.zoom) < 1e-9)
    #expect(abs(camera.longitude - even.longitude) < 1e-9)
    let world = 512 * pow(2, camera.zoom)
    let drop = (Self.y(even.latitude) - Self.y(camera.latitude)) * world
    #expect(abs(drop - 20) < 1e-6)
  }

  private static func y(_ latitude: Double) -> Double {
    (180 - (180 / .pi) * log(tan(.pi / 4 + latitude * .pi / 360))) / 360
  }

  @Test func sitesThatFitShallowerStillSplitTheGroup() {
    let sites = [Self.site(10, 10), Self.site(20, 30)]
    let camera = MapCamera.group(
      sites, splitting: 7, width: 390, height: 400, padding: MapPadding(32))!
    #expect(camera.zoom == 7)
  }

  @Test func sitesOnOneSpotStopAtTheDeepestZoom() {
    let sites = [Self.site(28.57, 34.54), Self.site(28.57, 34.54)]
    let camera = MapCamera.group(
      sites, splitting: 13, width: 390, height: 400, padding: MapPadding(32))!
    #expect(camera.zoom == MapCamera.maxZoom)
    #expect(abs(camera.latitude - 28.57) < 1e-9)
  }

  @Test func aFrameNoBiggerThanItsPaddingOpensAtTheSplit() {
    let sites = [Self.site(28.57, 34.54), Self.site(28.42, 34.45)]
    let camera = MapCamera.group(
      sites, splitting: 9, width: 60, height: 400, padding: MapPadding(32))!
    #expect(camera.zoom == 9)
  }

  @Test func sitesAcrossTheAntimeridianFitTheShortWayRound() {
    let sites = [Self.site(-17.8, 179.5), Self.site(-17.6, -179.5)]
    let camera = MapCamera.group(
      sites, splitting: 3, width: 390, height: 400, padding: MapPadding(32))!
    #expect(abs(abs(camera.longitude) - 180) < 1e-9)
    #expect(camera.zoom > 7)
  }
}
