import Testing

@testable import OpenDivingKit

struct MapPointTests {
  private func extent(_ bounds: LatLonBounds?, longitude: Double = 179) -> LatLonBounds {
    MapPoint(name: "Place", latitude: -17, longitude: longitude, bounds: bounds).extent
  }

  @Test func aPlaceWithNoBoxIsItsPoint() {
    #expect(extent(nil) == LatLonBounds(south: -17, north: -17, west: 179, east: 179))
  }

  @Test func aBoxRoundTheWorldIsAsWideAsItIsTallAroundThePlace() {
    let fiji = LatLonBounds(south: -22, north: -12, west: -180, east: 180)
    #expect(extent(fiji) == LatLonBounds(south: -22, north: -12, west: 174, east: 184))
    #expect(
      extent(fiji, longitude: -179) == LatLonBounds(south: -22, north: -12, west: -184, east: -174))
  }

  @Test func theWidthIsMeasuredAsTheUnionMeasuresIt() {
    let kiribati = LatLonBounds(south: -11, north: 5, west: -174.743, east: 177.049)
    #expect(extent(kiribati).east - extent(kiribati).west == 16)
    // East behind west by one degree is 359 the way the box runs.
    let wrapped = LatLonBounds(south: -22, north: -12, west: 1, east: 0)
    #expect(extent(wrapped) == LatLonBounds(south: -22, north: -12, west: 174, east: 184))
  }

  @Test func theLineIsAt350Degrees() {
    let atTheLine = LatLonBounds(south: -22, north: -12, west: -175, east: 175)
    #expect(extent(atTheLine) == LatLonBounds(south: -22, north: -12, west: 174, east: 184))
    let inside = LatLonBounds(south: -22, north: -12, west: -174.5, east: 175)
    #expect(extent(inside) == inside)
  }

  @Test func aBoxAcrossTheAntimeridianGivenProperlyStaysAsItWas() {
    let fiji = LatLonBounds(south: -21, north: -12, west: 176, east: -178)
    #expect(extent(fiji) == fiji)
  }
}
