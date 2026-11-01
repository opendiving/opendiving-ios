import Foundation

/// A page head's map as the tiles and pins that draw it, placed in the frame's points: the web
/// app's `MapBackdrop` fit, so a record's head shows the same square of the same map on both.
///
/// The places' extents are fitted over the frame and their pins into the band between the
/// bar over its top and the details over its bottom, the lesser zoom, floored to one the renderer draws tiles at and capped at
/// ``maxZoom``. The web draws its hero on a canvas 1024 points wide with fading sides; no
/// iPhone is that wide, so the frame here is the middle of that canvas and the fades never
/// show.
public struct MapBackdropLayout: Hashable, Sendable {
  /// One tile, its top-left corner in the frame. A tile past the antimeridian is the one it
  /// wraps to, so an address can appear twice.
  public struct Tile: Hashable, Sendable {
    public let address: MapTileAddress
    public let x: Double
    public let y: Double
  }

  /// One place, its centre in the frame.
  public struct Pin: Hashable, Sendable {
    public let name: String
    /// A position a dive computer recorded rather than a place somebody chose.
    public let isFix: Bool
    public let x: Double
    public let y: Double
  }

  /// The deepest a fit goes: a lone site opens where its coast is recognisable. The tiles stop
  /// here too.
  public static let maxZoom = 9
  /// How far the outermost place is kept from the frame's edges.
  static let fitPadding = 24.0

  public let tiles: [Tile]
  public let pins: [Pin]
  /// The side of a tile, in points.
  public var tileSize: Double { WebMercator.tileSize }

  /// Nil when there is nothing to place, or no frame to place it in.
  public init?(
    points: [MapPoint], fixes: [MapPoint], theme: MapTileTheme, width: Double, height: Double,
    coveredTop: Double = 0, coveredBottom: Double
  ) {
    let placed =
      points.map { Placed($0, isFix: false) } + fixes.map { Placed($0, isFix: true) }
    guard !placed.isEmpty, width > 0, height > 0 else { return nil }

    let padding = Self.fitPadding
    let bandTop = padding + coveredTop
    let bandBottom = min(padding + coveredBottom, height - bandTop - padding)
    let anchorX = WebMercator.round(width / 2)
    let anchorY = WebMercator.round((bandTop + height - bandBottom) / 2)

    let pinBounds = WebMercator.union(
      placed.map {
        LatLonBounds(south: $0.latitude, north: $0.latitude, west: $0.longitude, east: $0.longitude)
      })!
    let fitWidth = width - 2 * padding
    let zoom = min(
      Self.fitZoom(
        WebMercator.union(placed.map(\.bounds))!, width: fitWidth, height: height - 2 * padding),
      Self.fitZoom(pinBounds, width: fitWidth, height: height - bandTop - bandBottom))
    let centreLongitude = WebMercator.wrap(
      longitude: WebMercator.longitude(
        x: (WebMercator.x(longitude: pinBounds.west) + WebMercator.x(longitude: pinBounds.east))
          / 2))
    let centreLatitude = WebMercator.latitude(
      y: (WebMercator.y(latitude: WebMercator.clamp(latitude: pinBounds.south))
        + WebMercator.y(latitude: WebMercator.clamp(latitude: pinBounds.north))) / 2)

    // Floored, so the pins only draw closer and a tile's lettering stays the size it was drawn
    // at; the centre on a whole point, so the tiles meet without a seam.
    // A frame narrower than its padding fits nothing, a zoom of -∞ or NaN.
    let z = zoom.isNaN ? Self.maxZoom : Int(min(Double(Self.maxZoom), max(0, zoom)).rounded(.down))
    let count = 1 << z
    let worldSize = WebMercator.tileSize * Double(count)
    let originX = WebMercator.round(WebMercator.x(longitude: centreLongitude) * worldSize)
    let originY = WebMercator.round(
      WebMercator.y(latitude: WebMercator.clamp(latitude: centreLatitude)) * worldSize)

    let size = WebMercator.tileSize
    let first = Int(((originX - anchorX) / size).rounded(.down))
    let last = Int(((originX + width - anchorX) / size).rounded(.up)) - 1
    // Rows past the world's top or bottom edge have nothing to draw.
    let top = max(0, Int(((originY - anchorY) / size).rounded(.down)))
    let bottom = min(count - 1, Int(((originY + height - anchorY) / size).rounded(.up)) - 1)
    var tiles: [Tile] = []
    if top <= bottom {
      for row in top...bottom {
        for column in first...last {
          tiles.append(
            Tile(
              address: MapTileAddress(
                theme: theme, z: z, x: ((column % count) + count) % count, y: row),
              x: anchorX + Double(column) * size - originX,
              y: anchorY + Double(row) * size - originY))
        }
      }
    }
    self.tiles = tiles

    // Each pin on the copy of the world nearest the centre, so a trip across the antimeridian
    // keeps both sides.
    pins = placed.map { place in
      let across = WebMercator.x(longitude: place.longitude) - originX / worldSize
      return Pin(
        name: place.name, isFix: place.isFix,
        x: anchorX + (across - WebMercator.round(across)) * worldSize,
        y: anchorY + WebMercator.y(latitude: WebMercator.clamp(latitude: place.latitude))
          * worldSize - originY)
    }
  }

  /// The deepest zoom at which `box` fits `width` by `height`, capped at ``maxZoom``, which is
  /// also the answer when there is no room at all.
  private static func fitZoom(_ box: LatLonBounds, width: Double, height: Double) -> Double {
    guard width >= 0, height >= 0 else { return Double(maxZoom) }
    let spanX =
      (WebMercator.x(longitude: box.east) - WebMercator.x(longitude: box.west))
      * WebMercator.tileSize
    let spanY =
      (WebMercator.y(latitude: WebMercator.clamp(latitude: box.south))
        - WebMercator.y(latitude: WebMercator.clamp(latitude: box.north))) * WebMercator.tileSize
    return min(log2(min(width / spanX, height / spanY)), Double(maxZoom))
  }

  private struct Placed {
    let name: String
    let latitude: Double
    let longitude: Double
    let isFix: Bool
    let bounds: LatLonBounds

    init(_ point: MapPoint, isFix: Bool) {
      name = point.name
      latitude = point.latitude
      longitude = point.longitude
      self.isFix = isFix
      bounds =
        point.bounds
        ?? LatLonBounds(
          south: point.latitude, north: point.latitude, west: point.longitude,
          east: point.longitude)
    }
  }
}
