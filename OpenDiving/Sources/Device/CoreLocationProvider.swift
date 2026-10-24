import CoreLocation
import OpenDivingKit

/// The phone's position over CoreLocation's `CLLocationUpdate` stream: the first fix it
/// reports, after asking for when-in-use permission the first time. A fix that has not come
/// after twenty seconds — indoors, in airplane mode — is reported as unavailable rather than
/// left spinning.
final class CoreLocationProvider: LocationProvider {
  /// Held for the request: a manager that goes away mid-request cancels the prompt.
  private let manager = CLLocationManager()

  func currentLocation() async throws(LocationFailure) -> DeviceLocation {
    switch manager.authorizationStatus {
    case .denied, .restricted:
      throw .denied
    case .notDetermined:
      manager.requestWhenInUseAuthorization()
    default:
      break
    }
    let outcome = await withTaskGroup(of: Result<DeviceLocation, LocationFailure>.self) { group in
      group.addTask { await Self.firstFix() }
      group.addTask {
        try? await Task.sleep(for: .seconds(20))
        return .failure(.unavailable)
      }
      let first = await group.next() ?? .failure(.unavailable)
      group.cancelAll()
      return first
    }
    return try outcome.get()
  }

  private nonisolated static func firstFix() async -> Result<DeviceLocation, LocationFailure> {
    do {
      for try await update in CLLocationUpdate.liveUpdates() {
        if update.authorizationDenied || update.authorizationDeniedGlobally
          || update.authorizationRestricted
        {
          return .failure(.denied)
        }
        if let location = update.location {
          return .success(
            DeviceLocation(
              latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
        }
      }
    } catch {}
    return .failure(.unavailable)
  }
}
