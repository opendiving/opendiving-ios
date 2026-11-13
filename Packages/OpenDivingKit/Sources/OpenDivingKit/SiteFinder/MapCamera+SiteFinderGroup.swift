import Foundation

extension MapCamera {
  /// The camera a tap on one of the site finder's groups moves to: every site the group gathers
  /// fitted in a frame `width` by `height` points, `padding` in from its edges, the short way
  /// round the antimeridian. Never shallower than `splitting`, the zoom the group splits at, so a
  /// tap always opens it, and never deeper than ``maxZoom``, where sites on one spot stop it.
  /// The sites are centred in what the padding leaves, so an uneven one moves the camera off them.
  public static func group(
    _ sites: [MapPoint], splitting: Double, width: Double, height: Double, padding: MapPadding
  ) -> MapCamera? {
    guard let box = WebMercator.union(sites.map(\.extent)) else { return nil }
    let inner = (
      width: width - padding.left - padding.right, height: height - padding.top - padding.bottom
    )
    let fitted = MapBackdropLayout.fitZoom(
      box, width: inner.width, height: inner.height, deepest: maxZoom)
    // A frame no wider than its padding fits nothing, and a lone spot in it divides 0 by 0.
    let zoom = inner.width > 0 && inner.height > 0 && !fitted.isNaN ? fitted : splitting
    let settled = min(max(zoom, splitting), maxZoom)
    let world = WebMercator.tileSize * pow(2, settled)
    let middleY =
      (WebMercator.y(latitude: box.south) + WebMercator.y(latitude: box.north)) / 2
      - (padding.top - padding.bottom) / 2 / world
    let middleX =
      WebMercator.x(longitude: (box.west + box.east) / 2)
      - (padding.left - padding.right) / 2 / world
    return MapCamera(
      latitude: WebMercator.latitude(y: min(1, max(0, middleY))),
      longitude: WebMercator.wrap(longitude: WebMercator.longitude(x: middleX)),
      zoom: settled)
  }
}
