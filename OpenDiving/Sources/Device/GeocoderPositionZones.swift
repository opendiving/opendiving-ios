import CoreLocation
import OpenDivingKit

/// ``PositionZoneLookup`` over Apple's reverse geocoder, the one source of a position's zone that
/// needs no zone map in the app. `MKReverseGeocodingRequest`, which replaces it, starts at iOS 26.
final class GeocoderPositionZones: PositionZoneLookup {
  /// A boat's signal can hold a request open far longer than a download should wait on it.
  private static let patience: Duration = .seconds(5)

  func zone(latitude: Double, longitude: Double) async throws -> TimeZone? {
    let geocoder = CLGeocoder()
    let timeout = Task {
      try await Task.sleep(for: Self.patience)
      geocoder.cancelGeocode()
    }
    defer { timeout.cancel() }
    do {
      let location = CLLocation(latitude: latitude, longitude: longitude)
      return try await geocoder.reverseGeocodeLocation(location).first?.timeZone
    } catch let error as CLError where error.code == .geocodeFoundNoResult {
      return nil
    }
  }
}
