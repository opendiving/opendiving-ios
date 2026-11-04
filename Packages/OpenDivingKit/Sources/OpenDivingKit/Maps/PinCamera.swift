/// Where a map that places a pin looks, by the web's `MapPicker` rule: a position from anywhere
/// else brings the camera to it, and the map's own pick, coming back through the form, does not.
public struct PinCamera: Hashable, Sendable {
  public private(set) var camera: MapCamera

  /// The position as the form last held it.
  private var position: DeviceLocation?
  /// The map's own pick on its way back through the form. Spent on its first match: kept, it
  /// would read a position typed back much later as an echo and leave the camera behind.
  private var pick: DeviceLocation?
  /// Latched, so half-typed text that parses to nothing does not make the next keystroke a
  /// first position.
  private var everPlaced: Bool

  /// A form with no position opens on the world, and one with a position there at the placed
  /// zoom.
  public init(position: DeviceLocation?) {
    self.position = position
    everPlaced = position != nil
    camera =
      position.map {
        MapCamera(latitude: $0.latitude, longitude: $0.longitude, zoom: MapCamera.placedZoom)
      } ?? .world
  }

  /// The map came to rest somewhere: a gesture's, or the map's own account of a move asked of it.
  public mutating func moved(to camera: MapCamera) {
    self.camera = camera
  }

  /// A pick is about to go to the form. `position` is what the form will hand back, its text
  /// read as the form reads it, since nothing else equals what returns. A pick of the position
  /// already held arms nothing: no change is coming to spend it.
  public mutating func picked(_ position: DeviceLocation) {
    pick = position == self.position ? nil : position
  }

  /// The form's position, which may have changed.
  public mutating func follow(_ position: DeviceLocation?) {
    guard position != self.position else { return }
    let isEcho = position != nil && position == pick
    let isFirst = !everPlaced
    self.position = position
    if isEcho { pick = nil }
    guard let position else { return }
    everPlaced = true
    guard !isEcho else { return }
    camera = MapCamera(
      latitude: position.latitude, longitude: position.longitude,
      zoom: isFirst ? max(camera.zoom, MapCamera.placedZoom) : camera.zoom)
  }

  /// A coordinate the map reported, folded into what the form accepts: the latitude inside Web
  /// Mercator's cut and the longitude in [-180, 180) (`positionOf`).
  public static func folded(latitude: Double, longitude: Double) -> DeviceLocation {
    DeviceLocation(
      latitude: WebMercator.clamp(latitude: latitude),
      longitude: WebMercator.wrap(longitude: longitude))
  }
}
