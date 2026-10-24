/// Where the phone is, for *Use my location* on a new dive site. A protocol because the Kit
/// builds where CoreLocation does not exist: the app target conforms it over the device's
/// location services, and a view model's tests over a fake.
@MainActor
public protocol LocationProvider: AnyObject {
  /// One fix, asking the diver's permission first where it has not been given or refused.
  func currentLocation() async throws(LocationFailure) -> DeviceLocation
}

/// A position the phone reported, in decimal degrees.
public struct DeviceLocation: Hashable, Sendable {
  public let latitude: Double
  public let longitude: Double

  public init(latitude: Double, longitude: Double) {
    self.latitude = latitude
    self.longitude = longitude
  }
}

/// Why no position came back.
public enum LocationFailure: Error, Hashable, Sendable {
  /// The diver refused the app their location, or the device restricts it.
  case denied
  /// No fix could be had: location services are off, or the phone could not tell.
  case unavailable

  /// The sentence the site sheet shows under *Use my location*.
  public var message: String {
    switch self {
    case .denied:
      "OpenDiving may not use your location. You can allow it in Settings."
    case .unavailable:
      "Your location could not be found. Type the coordinates, or place the site on the map."
    }
  }
}
