import Foundation

/// How far apart two recorded positions are — a dive's entry and exit fixes — and how to
/// say it. A map at a phone's zoom draws a swim's drift as one dot, so it is text.
public enum GeoDistance {
  /// Mean Earth radius (IUGG), in metres: a sphere, whose error is far below a dive
  /// computer's own fix error after a swim under water.
  static let earthRadiusMeters = 6_371_008.8

  /// Great-circle distance in metres by haversine, which works on the difference of the
  /// longitudes and so crosses the antimeridian without going round the world.
  public static func haversineMeters(
    fromLatitude latitude1: Double, longitude longitude1: Double,
    toLatitude latitude2: Double, longitude longitude2: Double
  ) -> Double {
    let lat1 = radians(latitude1)
    let lat2 = radians(latitude2)
    let deltaLat = lat2 - lat1
    let deltaLon = radians(longitude2 - longitude1)

    let h =
      pow(sin(deltaLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(deltaLon / 2), 2)
    return 2 * earthRadiusMeters * asin(min(1, h.squareRoot()))
  }

  /// Whole metres below a kilometre, then one decimal of kilometres; whole feet below a
  /// mile, then one decimal of miles. Rounded before the comparison, so 999.6 m reads
  /// `1.0 km` rather than `1000 m`.
  public static func format(_ meters: Double, _ units: UnitSystem) -> String {
    if units == .imperial {
      let feet = meters / UnitFormat.metersPerFoot
      let wholeFeet = NumberText.round(feet)
      if wholeFeet < UnitFormat.feetPerMile { return NumberText.plain(wholeFeet) + " ft" }
      return NumberText.fixed(feet / UnitFormat.feetPerMile, decimals: 1) + " mi"
    }
    let wholeMeters = NumberText.round(meters)
    if wholeMeters < 1000 { return NumberText.plain(wholeMeters) + " m" }
    return NumberText.fixed(meters / 1000, decimals: 1) + " km"
  }

  private static func radians(_ degrees: Double) -> Double {
    degrees * Double.pi / 180
  }
}
