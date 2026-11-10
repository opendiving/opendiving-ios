import Foundation

extension MapCamera {
  /// The camera a tap on one of the site finder's groups moves to: every site the group gathers
  /// fitted in a frame `width` by `height` points, `padding` in from each edge, the short way
  /// round the antimeridian. Never shallower than `splitting`, the zoom the group splits at, so a
  /// tap always opens it, and never deeper than ``maxZoom``, where sites on one spot stop it.
  public static func group(
    _ sites: [MapPoint], splitting: Double, width: Double, height: Double, padding: Double
  ) -> MapCamera? {
    guard let box = WebMercator.union(sites.map(\.extent)) else { return nil }
    let fitted = MapBackdropLayout.fitZoom(
      box, width: width - 2 * padding, height: height - 2 * padding, deepest: maxZoom)
    // A frame no wider than its padding fits nothing, and a lone spot in it divides 0 by 0.
    let zoom = width > 2 * padding && height > 2 * padding && !fitted.isNaN ? fitted : splitting
    return MapCamera(
      latitude: WebMercator.latitude(
        y: (WebMercator.y(latitude: box.south) + WebMercator.y(latitude: box.north)) / 2),
      longitude: WebMercator.wrap(longitude: (box.west + box.east) / 2),
      zoom: min(max(zoom, splitting), maxZoom))
  }
}
