import Foundation
import Testing

@testable import OpenDivingKit

/// The expected tiles and pins are the web app's: its `frameCamera`, `tileLayout` and
/// `projectFrom` run over the same places and frame, so a page head shows the same square on
/// both.
struct MapBackdropLayoutTests {
  private func layout(
    _ points: [MapPoint], fixes: [MapPoint] = [], width: Double, height: Double,
    coveredBottom: Double
  ) throws -> MapBackdropLayout {
    try #require(
      MapBackdropLayout(
        points: points, fixes: fixes, theme: .light, width: width, height: height,
        coveredBottom: coveredBottom))
  }

  private func tiles(_ layout: MapBackdropLayout) -> [[Double]] {
    layout.tiles.map {
      [Double($0.address.z), Double($0.address.x), Double($0.address.y), $0.x, $0.y]
    }
  }

  private func expectPins(_ layout: MapBackdropLayout, _ expected: [(Double, Double)]) {
    #expect(layout.pins.count == expected.count)
    for (pin, (x, y)) in zip(layout.pins, expected) {
      #expect(abs(pin.x - x) < 1e-6 && abs(pin.y - y) < 1e-6, "\(pin) is not at \(x), \(y)")
    }
  }

  @Test func aSiteAndItsFixOpenAtTheDeepestZoomInTheBandAboveTheDetails() throws {
    let layout = try layout(
      [MapPoint(name: "Blue Hole", latitude: 28.5722, longitude: 34.5372)],
      fixes: [MapPoint(name: "Exit", latitude: 28.5735, longitude: 34.5361)],
      width: 393, height: 280, coveredBottom: 150)
    #expect(tiles(layout) == [[9, 304, 213, -376, -225], [9, 305, 213, 136, -225]])
    expectPins(
      layout, [(197.22154666666756, 65.21723197239044), (196.42055111110676, 64.13932187619503)])
    #expect(layout.pins.map(\.isFix) == [false, true])
  }

  @Test func placesEitherSideOfTheAntimeridianAreFittedTheShortWayRound() throws {
    let layout = try layout(
      [
        MapPoint(name: "Fiji", latitude: -17.7, longitude: 178.0),
        MapPoint(name: "Samoa", latitude: -13.8, longitude: -172.1),
      ], width: 393, height: 280, coveredBottom: 150)
    #expect(tiles(layout) == [[3, 7, 4, -349, -117], [3, 0, 4, 163, -117]])
    expectPins(
      layout, [(140.24444444444453, 87.66844914814374), (252.8844444444445, 41.55382024545679)])
  }

  @Test func aPlaceWithAFootprintIsFittedByIt() throws {
    let egypt = MapPoint(
      name: "Egypt", latitude: 26.8, longitude: 30.8,
      bounds: LatLonBounds(south: 22, north: 31.7, west: 24.7, east: 36.9))
    let layout = try layout([egypt], width: 430, height: 300, coveredBottom: 120)
    #expect(
      tiles(layout) == [
        [4, 8, 6, -486, -301], [4, 9, 6, 26, -301], [4, 8, 7, -486, 211], [4, 9, 7, 26, 211],
      ])
    expectPins(layout, [(214.87111111111153, 89.61372488227607)])
  }

  @Test func nothingToPlaceOrNoFrameIsNoLayout() {
    let site = MapPoint(name: "Blue Hole", latitude: 28.5722, longitude: 34.5372)
    #expect(
      MapBackdropLayout(
        points: [], fixes: [], theme: .light, width: 393, height: 280, coveredBottom: 0) == nil)
    #expect(
      MapBackdropLayout(
        points: [site], fixes: [], theme: .light, width: 0, height: 280, coveredBottom: 0) == nil)
  }

  @Test func aFrameNarrowerThanItsPaddingStillLaysOutTiles() throws {
    let layout = try layout(
      [MapPoint(name: "Blue Hole", latitude: 28.5722, longitude: 34.5372)],
      width: 40, height: 40, coveredBottom: 0)
    #expect(!layout.tiles.isEmpty)
  }

  @Test func theThemeIsEveryTilesAddress() throws {
    let layout = try #require(
      MapBackdropLayout(
        points: [MapPoint(name: "Blue Hole", latitude: 28.5722, longitude: 34.5372)], fixes: [],
        theme: .dark, width: 393, height: 280, coveredBottom: 150))
    #expect(layout.tiles.allSatisfy { $0.address.theme == .dark })
  }
}
