import Foundation
import Testing

@testable import OpenDivingKit

/// The expected tiles and pins are the web app's: its `frameCamera`, `tileLayout` and
/// `projectFrom` run over the same places and frame, so a page head shows the same square on
/// both, but for the whole points that bring the places' middle back onto the band's.
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
    #expect(tiles(layout) == [[9, 304, 213, -377, -225], [9, 305, 213, 135, -225]])
    expectPins(
      layout, [(196.22154666666756, 65.21723197239044), (195.42055111110676, 64.13932187619503)])
    #expect(layout.pins.map(\.isFix) == [false, true])
  }

  @Test func aDivesSiteLandsInTheBandsMiddleToThePixelWhereverItsFixesAre() throws {
    let site = MapPoint(name: "Blue Hole", latitude: 28.5722, longitude: 34.5372)
    let fixes = [
      MapPoint(name: "Entry", latitude: 28.58, longitude: 34.55),
      MapPoint(name: "Exit", latitude: 28.581, longitude: 34.552),
    ]
    for scale in [2.0, 3.0] {
      let alone = try #require(
        MapBackdropLayout(
          points: [site], fixes: [], theme: .light, width: 361, height: 240, coveredBottom: 101,
          scale: scale))
      let dived = try #require(
        MapBackdropLayout(
          points: [site], fixes: fixes, theme: .light, width: 361, height: 240,
          coveredBottom: 101, scale: scale))
      for layout in [alone, dived] {
        let pin = try #require(layout.pins.first)
        #expect(abs(pin.x - 180.5) <= 0.5 / scale)
        #expect(abs(pin.y - (240 - 101) / 2) <= 0.5 / scale)
        #expect(layout.tiles.allSatisfy { abs(($0.x * scale).rounded() - $0.x * scale) < 1e-9 })
      }
    }
  }

  @Test func aFixFarFromItsSiteStaysInTheBandWithTheSiteInItsMiddle() throws {
    let site = MapPoint(name: "Blue Hole", latitude: 28.5722, longitude: 34.5372)
    let harbour = MapPoint(name: "Entry", latitude: 28.95, longitude: 34.1)
    let layout = try #require(
      MapBackdropLayout(
        points: [site], fixes: [harbour], theme: .light, width: 361, height: 240,
        coveredBottom: 101, scale: 3))
    let padding = MapBackdropLayout.fitPadding
    #expect(abs(layout.pins[0].x - 180.5) <= 0.5 / 3)
    for pin in layout.pins {
      #expect((padding...(361 - padding)).contains(pin.x), "\(pin)")
      #expect((padding...(240 - 101 - padding)).contains(pin.y), "\(pin)")
    }
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

  @Test func aBarOverTheTopKeepsThePinsBelowIt() throws {
    let points = [
      MapPoint(name: "Fiji", latitude: -17.7, longitude: 178.0),
      MapPoint(name: "Samoa", latitude: -13.8, longitude: -172.1),
    ]
    let open = try #require(
      MapBackdropLayout(
        points: points, fixes: [], theme: .light, width: 393, height: 280, coveredBottom: 150))
    let covered = try #require(
      MapBackdropLayout(
        points: points, fixes: [], theme: .light, width: 393, height: 380, coveredTop: 100,
        coveredBottom: 150))
    #expect(covered.pins.allSatisfy { $0.y >= 100 + MapBackdropLayout.fitPadding })
    #expect(covered.tiles.map(\.address) == open.tiles.map(\.address))
  }

  @Test func whatOnlyAPullDownShowsTakesTilesButNoPartInTheFit() throws {
    // Taller than it is wide, so the frame's height decides its zoom.
    let maldives = MapPoint(
      name: "Maldives", latitude: 3.2, longitude: 73.2,
      bounds: LatLonBounds(south: -0.7, north: 7.1, west: 72.6, east: 73.8))
    let shown = try layout([maldives], width: 300, height: 340, coveredBottom: 120)
    let pulled = try #require(
      MapBackdropLayout(
        points: [maldives], fixes: [], theme: .light, width: 300, height: 740, overflowTop: 400,
        coveredBottom: 120))
    #expect(pulled.tiles.map(\.address.z) == pulled.tiles.map { _ in shown.tiles[0].address.z })
    #expect(Set(shown.tiles.map(\.address)).isSubset(of: pulled.tiles.map(\.address)))
    #expect(pulled.tiles.map(\.y).min()! <= 0)
    expectPins(pulled, shown.pins.map { ($0.x, $0.y + 400) })
  }

  @Test func aBoxThatCirclesTheWorldKeepsItsPinsInTheFrame() throws {
    let fiji = MapPoint(
      name: "Fiji", latitude: -17, longitude: 179,
      bounds: LatLonBounds(south: -22, north: -12, west: -180, east: 180))
    let apia = MapPoint(name: "Apia", latitude: -13.8, longitude: -171.8)
    for points in [[fiji], [fiji, apia]] {
      let head = try layout(points, width: 393, height: 280, coveredBottom: 150)
      #expect(head.tiles[0].address.z >= 3)
      #expect(head.pins.allSatisfy { (0...393).contains($0.x) && (0...280).contains($0.y) })
    }
  }

  @Test func nothingPlacedCanStillBeTheWholeWorld() throws {
    #expect(
      MapBackdropLayout(
        points: [], fixes: [], theme: .light, width: 361, height: 240, coveredBottom: 100) == nil)
    let world = try #require(
      MapBackdropLayout(
        points: [], fixes: [], theme: .light, width: 361, height: 240, coveredBottom: 100,
        worldWhenEmpty: true))
    #expect(world.pins.isEmpty)
    #expect(Set(world.tiles.map(\.address)) == [MapTileAddress(theme: .light, z: 0, x: 0, y: 0)])
    // The equator across the band's middle, between the padding and the details.
    let equator = world.tiles[0].y + world.tileSize / 2
    #expect(equator == WebMercator.round((24 + 240 - 124) / 2.0))
  }

  @Test func theThemeIsEveryTilesAddress() throws {
    let layout = try #require(
      MapBackdropLayout(
        points: [MapPoint(name: "Blue Hole", latitude: 28.5722, longitude: 34.5372)], fixes: [],
        theme: .dark, width: 393, height: 280, coveredBottom: 150))
    #expect(layout.tiles.allSatisfy { $0.address.theme == .dark })
  }
}
