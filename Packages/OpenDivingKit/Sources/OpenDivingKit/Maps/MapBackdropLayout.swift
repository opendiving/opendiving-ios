import Foundation

/// A page head's map as the tiles and pins that draw it, placed in the frame's points: the web
/// app's `MapBackdrop` fit, so a record's head shows the same map on both, centred on its places
/// rather than their fixes and to the pixel.
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
  public static let fitPadding = 24.0

  public let tiles: [Tile]
  public let pins: [Pin]
  /// The side of a tile, in points.
  public var tileSize: Double { WebMercator.tileSize }

  /// Nil when there is nothing to place, or no frame to place it in; with nothing to place
  /// and `worldWhenEmpty`, the whole world at zoom 0, the equator across the band's middle.
  /// The top `overflowTop` points of the frame are out of sight until a pull-down shows
  /// them: tiles are laid out there, but nothing is fitted into them.
  ///
  /// Every place is fitted, but the band's middle is the places' own, the fixes' only where
  /// there are no places: a dive's site sits where a site's does, its fixes around it. That
  /// middle lands on the band's to the nearest of the screen's pixels, `scale` to a point.
  public init?(
    points: [MapPoint], fixes: [MapPoint], theme: MapTileTheme, width: Double, height: Double,
    overflowTop: Double = 0, coveredTop: Double = 0, coveredBottom: Double,
    worldWhenEmpty: Bool = false, scale: Double = 1
  ) {
    let placed =
      points.map { Placed($0, isFix: false) } + fixes.map { Placed($0, isFix: true) }
    guard !placed.isEmpty || worldWhenEmpty, width > 0, height > 0 else { return nil }

    let padding = Self.fitPadding
    let shown = height - overflowTop
    let bandTop = overflowTop + padding + coveredTop
    let bandBottom = min(padding + coveredBottom, shown - padding - coveredTop - padding)
    let anchorX = WebMercator.round(width / 2)
    let anchorY = WebMercator.round((bandTop + height - bandBottom) / 2)

    let zoom: Double
    let centreLongitude: Double
    let centreLatitude: Double
    if let pinBounds = WebMercator.union(
      placed.map {
        LatLonBounds(south: $0.latitude, north: $0.latitude, west: $0.longitude, east: $0.longitude)
      })
    {
      let centred = placed.contains { !$0.isFix } ? placed.filter { !$0.isFix } : placed
      let centreBounds = WebMercator.union(
        centred.map {
          LatLonBounds(
            south: $0.latitude, north: $0.latitude, west: $0.longitude, east: $0.longitude)
        })!
      centreLongitude = WebMercator.wrap(
        longitude: WebMercator.longitude(
          x: (WebMercator.x(longitude: centreBounds.west)
            + WebMercator.x(longitude: centreBounds.east)) / 2))
      centreLatitude = WebMercator.latitude(
        y: (WebMercator.y(latitude: WebMercator.clamp(latitude: centreBounds.south))
          + WebMercator.y(latitude: WebMercator.clamp(latitude: centreBounds.north))) / 2)
      let fitWidth = width - 2 * padding
      zoom = min(
        Self.fitZoom(
          WebMercator.union(placed.map(\.bounds))!, width: fitWidth, height: shown - 2 * padding),
        Self.fitZoom(
          Self.mirrored(pinBounds, longitude: centreLongitude, latitude: centreLatitude),
          width: fitWidth, height: height - bandTop - bandBottom))
    } else {
      zoom = 0
      centreLongitude = 0
      centreLatitude = 0
    }

    // Floored, so the pins only draw closer and a tile's lettering stays the size it was drawn
    // at; the centre on a whole point, so the tiles meet without a seam.
    // A frame narrower than its padding fits nothing, a zoom of -∞ or NaN.
    let z = zoom.isNaN ? Self.maxZoom : Int(min(Double(Self.maxZoom), max(0, zoom)).rounded(.down))
    let count = 1 << z
    let worldSize = WebMercator.tileSize * Double(count)
    let originX = WebMercator.round(WebMercator.x(longitude: centreLongitude) * worldSize)
    let originY = WebMercator.round(
      WebMercator.y(latitude: WebMercator.clamp(latitude: centreLatitude)) * worldSize)

    // The anchor and the origin are whole points, so the tiles meet without a seam, and each
    // rounding can move the middle half a point off the band's; the whole map is moved back by
    // whole pixels, which keeps the seams closed.
    let snap = { (value: Double) in (value * scale).rounded() / scale }
    let shiftX = snap(
      width / 2 - (anchorX + WebMercator.x(longitude: centreLongitude) * worldSize - originX))
    let shiftY = snap(
      (bandTop + height - bandBottom) / 2
        - (anchorY + WebMercator.y(latitude: WebMercator.clamp(latitude: centreLatitude))
          * worldSize - originY))
    let shownX = anchorX + shiftX
    let shownY = anchorY + shiftY

    let size = WebMercator.tileSize
    let first = Int(((originX - shownX) / size).rounded(.down))
    let last = Int(((originX + width - shownX) / size).rounded(.up)) - 1
    // Rows past the world's top or bottom edge have nothing to draw.
    let top = max(0, Int(((originY - shownY) / size).rounded(.down)))
    let bottom = min(count - 1, Int(((originY + height - shownY) / size).rounded(.up)) - 1)
    var tiles: [Tile] = []
    if top <= bottom {
      for row in top...bottom {
        for column in first...last {
          tiles.append(
            Tile(
              address: MapTileAddress(
                theme: theme, z: z, x: ((column % count) + count) % count, y: row),
              x: shownX + Double(column) * size - originX,
              y: shownY + Double(row) * size - originY))
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
        x: shownX + (across - WebMercator.round(across)) * worldSize,
        y: shownY + WebMercator.y(latitude: WebMercator.clamp(latitude: place.latitude))
          * worldSize - originY)
    }
  }

  /// `box` grown to reach as far on each side of the centre as its farthest side does, so a fit
  /// of it holds with the centre in the middle: the places' own box where the centre is its
  /// middle, more where fixes lie off to one side of the sites.
  static func mirrored(_ box: LatLonBounds, longitude: Double, latitude: Double) -> LatLonBounds {
    let centreX =
      longitude + (((box.west + box.east) / 2 - longitude) / 360).rounded() * 360
    let halfX = max(abs(box.west - centreX), abs(box.east - centreX))
    let centreY = WebMercator.y(latitude: WebMercator.clamp(latitude: latitude))
    let halfY = max(
      abs(WebMercator.y(latitude: WebMercator.clamp(latitude: box.south)) - centreY),
      abs(WebMercator.y(latitude: WebMercator.clamp(latitude: box.north)) - centreY))
    return LatLonBounds(
      south: WebMercator.latitude(y: min(1, centreY + halfY)),
      north: WebMercator.latitude(y: max(0, centreY - halfY)),
      west: centreX - halfX, east: centreX + halfX)
  }

  /// The deepest zoom at which `box` fits `width` by `height`, capped at `deepest`, which is
  /// also the answer when there is no room at all.
  static func fitZoom(
    _ box: LatLonBounds, width: Double, height: Double, deepest: Double = Double(maxZoom)
  ) -> Double {
    guard width >= 0, height >= 0 else { return deepest }
    let spanX =
      (WebMercator.x(longitude: box.east) - WebMercator.x(longitude: box.west))
      * WebMercator.tileSize
    let spanY =
      (WebMercator.y(latitude: WebMercator.clamp(latitude: box.south))
        - WebMercator.y(latitude: WebMercator.clamp(latitude: box.north))) * WebMercator.tileSize
    return min(log2(min(width / spanX, height / spanY)), deepest)
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
      bounds = point.extent
    }
  }
}
