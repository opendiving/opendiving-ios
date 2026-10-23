import OpenDivingKit
import Testing

/// Transcribed from `src/lib/geo-distance.test.ts` and, for coordinates,
/// `src/lib/validations/dive-site.test.ts:218-235` at `opendiving-web` `ec014ff9`.
struct GeoDistanceTests {
  @Test func haversine() {
    let degree = GeoDistance.haversineMeters(
      fromLatitude: 0, longitude: 0, toLatitude: 1, longitude: 0)
    #expect(abs(degree - 111_195) < 5)
    let swim = GeoDistance.haversineMeters(
      fromLatitude: 28.4375, longitude: 34.4584, toLatitude: 28.4392, longitude: 34.4571)
    #expect(abs(swim - 227.8) < 0.05)
    let antimeridian = GeoDistance.haversineMeters(
      fromLatitude: 0, longitude: 179.9999, toLatitude: 0, longitude: -179.9999)
    #expect(abs(antimeridian - 22.24) < 0.005)
    #expect(
      GeoDistance.haversineMeters(
        fromLatitude: 28.4375, longitude: 34.4584, toLatitude: 28.4375, longitude: 34.4584) == 0)
  }

  @Test(
    arguments: [
      (0.0, UnitSystem.metric, "0 m"), (211.6, .metric, "212 m"), (999.4, .metric, "999 m"),
      (999.5, .metric, "1.0 km"), (1000, .metric, "1.0 km"), (1249, .metric, "1.2 km"),
      (12345, .metric, "12.3 km"), (0, .imperial, "0 ft"), (211.6, .imperial, "694 ft"),
      (1609, .imperial, "5279 ft"), (1609.344, .imperial, "1.0 mi"), (2000, .imperial, "1.2 mi"),
      (12345, .imperial, "7.7 mi"),
    ] as [(Double, UnitSystem, String)])
  func distance(meters: Double, units: UnitSystem, expected: String) {
    #expect(GeoDistance.format(meters, units) == expected)
  }

  @Test func coordinates() {
    #expect(CoordinateFormat.format(latitude: 27.8506, longitude: 34.3136) == "27.8506, 34.3136")
    #expect(CoordinateFormat.format(latitude: nil, longitude: nil) == nil)
    #expect(CoordinateFormat.format(latitude: 27.8506, longitude: nil) == nil)
    #expect(CoordinateFormat.format(latitude: nil, longitude: 34.3136) == nil)
    #expect(CoordinateFormat.format(latitude: 0, longitude: 34.3136) == "0, 34.3136")
    #expect(CoordinateFormat.format(latitude: 5e-7, longitude: 34.3136) == "0.0000005, 34.3136")
  }
}
