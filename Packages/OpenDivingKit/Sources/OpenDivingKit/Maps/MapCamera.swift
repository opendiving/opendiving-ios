import Foundation

/// Where a form's map looks, in MapLibre's units: a zoom is a world 512 points wide at zoom 0, the
/// same on the phone as in the web's GL JS, so the web's numbers carry over unchanged.
public struct MapCamera: Hashable, Sendable {
  /// Close enough to see a jetty, far enough out to see which bay it is in (`PLACED_ZOOM`).
  public static let placedZoom = 11.0
  public static let maxZoom = 17.0
  public static let minZoom = 0.0
  /// What a map with nothing on it opens on: the whole world, a little north of the equator,
  /// where the land is (`WORLD_CENTER`).
  public static let world = MapCamera(latitude: 20, longitude: 0, zoom: minZoom)

  public var latitude: Double
  public var longitude: Double
  public var zoom: Double

  public init(latitude: Double, longitude: Double, zoom: Double) {
    self.latitude = latitude
    self.longitude = longitude
    self.zoom = zoom
  }

  /// The camera that fits `points` in a frame, each by its footprint where it has one, the short
  /// way round the antimeridian and no deeper than a page head's map; ``world`` with nothing to
  /// fit, or no frame to fit it in.
  public static func fit(_ points: [MapPoint], width: Double, height: Double) -> MapCamera {
    guard width > 0, height > 0, let box = WebMercator.union(points.map(\.extent)) else {
      return world
    }
    let padding = MapBackdropLayout.fitPadding
    let fitted = MapBackdropLayout.fitZoom(
      box, width: width - 2 * padding, height: height - 2 * padding)
    // A frame no wider than its padding around a lone point divides nothing by nothing.
    let zoom = fitted.isNaN ? Double(MapBackdropLayout.maxZoom) : max(minZoom, fitted)
    return MapCamera(
      latitude: WebMercator.latitude(
        y: (WebMercator.y(latitude: box.south) + WebMercator.y(latitude: box.north)) / 2),
      longitude: WebMercator.wrap(longitude: (box.west + box.east) / 2), zoom: zoom)
  }
}
