import Foundation

/// An extent in degrees. `east` may pass 180 for an extent across the antimeridian.
public struct LatLonBounds: Hashable, Sendable {
  public var south: Double
  public var north: Double
  public var west: Double
  public var east: Double

  public init(south: Double, north: Double, west: Double, east: Double) {
    self.south = south
    self.north = north
    self.west = west
    self.east = east
  }

  /// The degrees from west to east. Signed first, so a box across the antimeridian, its east
  /// behind its west, stays one interval.
  var longitudeSpan: Double {
    let signed = east - west
    return signed >= 0 ? min(signed, 360) : signed + 360
  }
}

/// The grid every map tile belongs to, in the web app's and the renderer's spelling of it, so
/// a pin lands on the pixel the tile drew its place at.
enum WebMercator {
  /// A tile's side in points: the renderer draws 512 at pixel ratio 2.
  static let tileSize = 512.0
  /// Where Web Mercator is cut, which makes the projected world square.
  static let maxLatitude = 85.0511287798066

  static func x(longitude: Double) -> Double {
    (180 + longitude) / 360
  }

  static func y(latitude: Double) -> Double {
    (180 - (180 / .pi) * log(tan(.pi / 4 + latitude * .pi / 360))) / 360
  }

  static func longitude(x: Double) -> Double {
    x * 360 - 180
  }

  static func latitude(y: Double) -> Double {
    (360 / .pi) * atan(exp((180 - y * 360) * .pi / 180)) - 90
  }

  static func clamp(latitude: Double) -> Double {
    min(maxLatitude, max(-maxLatitude, latitude))
  }

  /// Halves rounded up, as JavaScript's `Math.round` does, so a tile and a pin land on the
  /// point the web's land on.
  static func round(_ value: Double) -> Double {
    (value + 0.5).rounded(.down)
  }

  /// Folded into [-180, 180), so exactly 180 comes back as -180.
  static func wrap(longitude: Double) -> Double {
    (((longitude + 180).truncatingRemainder(dividingBy: 360)) + 360)
      .truncatingRemainder(dividingBy: 360) - 180
  }

  /// The smallest extent holding every box, unwrapped against the first box's west edge so
  /// Fiji and Samoa are six degrees apart rather than 354.
  static func union(_ boxes: [LatLonBounds]) -> LatLonBounds? {
    guard let first = boxes.first else { return nil }
    var south = maxLatitude
    var north = -maxLatitude
    var west = Double.infinity
    var east = -Double.infinity
    let reference = wrap(longitude: first.west)
    for box in boxes {
      south = min(south, clamp(latitude: min(box.south, box.north)))
      north = max(north, clamp(latitude: max(box.south, box.north)))
      var boxWest = wrap(longitude: box.west)
      boxWest += round((reference - boxWest) / 360) * 360
      west = min(west, boxWest)
      east = max(east, boxWest + box.longitudeSpan)
    }
    if east - west >= 360 {
      west = -180
      east = 180
    }
    return LatLonBounds(south: south, north: north, west: west, east: east)
  }
}
