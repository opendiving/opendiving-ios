import Foundation

extension SiteFinderModel {
  /// The site the sites map's weather bar is for: where its weather is asked about, and what it is
  /// titled.
  public struct WeatherSite: Hashable, Sendable {
    public let uuid: UUID
    public let pin: DeviceLocation
    /// Its place, else its name; nil while an open site's panel reads it.
    public let title: String?
  }

  /// Zoomed in this far or closer, the map's view is an area a diver picks a site in, about fifty
  /// kilometres across on a phone; further out, the site nearest the centre may be anywhere in a
  /// country, and its weather says nothing of what the diver is looking at.
  public static let weatherZoom = 9.0

  /// The open site; with none open and the map zoomed in to ``weatherZoom``, the site drawn nearest
  /// the middle of what the map shows; else nil.
  public var weatherSite: WeatherSite? {
    if let opened {
      return opened.pin.map { WeatherSite(uuid: opened.uuid, pin: $0, title: opened.weatherTitle) }
    }
    guard camera.zoom >= Self.weatherZoom, let box = shownBox else { return nil }
    var nearest: (uuid: UUID, name: String, pin: DeviceLocation, meters: Double)?
    func consider(_ uuid: UUID, _ name: String, _ latitude: Double, _ longitude: Double) {
      guard Self.contains(box, latitude: latitude, longitude: longitude) else { return }
      let meters = GeoDistance.haversineMeters(
        fromLatitude: camera.latitude, longitude: camera.longitude, toLatitude: latitude,
        longitude: longitude)
      guard meters < nearest?.meters ?? .infinity else { return }
      nearest = (uuid, name, DeviceLocation(latitude: latitude, longitude: longitude), meters)
    }
    // What the map draws: the diver's sites, and the Commons' unless the finder shows only theirs.
    for point in points.yours {
      consider(point.uuid, point.name, point.latitude, point.longitude)
    }
    if !yours {
      for point in points.commons?.points ?? [] {
        consider(point.uuid, point.name, point.latitude, point.longitude)
      }
    }
    guard let nearest else { return nil }
    return WeatherSite(
      uuid: nearest.uuid, pin: nearest.pin,
      title: listedLocation(nearest.uuid) ?? nearest.name.trimmedOfWhitespace)
  }

  /// The place the list names a site in, where the list has a row for it.
  private func listedLocation(_ uuid: UUID) -> String? {
    for row in rows {
      guard case .site(let item) = row, item.site.ref.serverUUID == uuid else { continue }
      let name = item.site.location?.name.trimmedOfWhitespace ?? ""
      return name.isEmpty ? nil : name
    }
    return nil
  }

  /// Whether a box holds a position. The camera's box runs either side of its centre without
  /// wrapping, so a longitude is measured from the middle, which holds across the antimeridian.
  static func contains(_ box: LatLonBounds, latitude: Double, longitude: Double) -> Bool {
    guard (box.south...box.north).contains(latitude) else { return false }
    let half = (box.east - box.west) / 2
    return abs(WebMercator.wrap(longitude: longitude - (box.west + half))) <= half
  }
}
