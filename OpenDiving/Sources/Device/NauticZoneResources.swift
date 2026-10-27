@preconcurrency import Clibdivecomputer
import Foundation
@preconcurrency import LibDCBridge
@preconcurrency import LibDCSwift

/// The settings resources the Suunto app reads a watch's time zone from, fetched over the open
/// link. A resource `fetch` rejects is fetched again raw, unvalidated, so its bytes are still
/// what the decode sees.
nonisolated enum NauticZoneResources {
  static let paths = [
    "/Settings/General/TimeZoneInfo",
    "/Settings/User/Time/LocalTime/Offset",
    "/Settings/User/Time/LocalTime/TimeZone",
    "/Dev/Time",
  ]

  /// One resource as the watch answered it.
  struct Resource: Sendable {
    var path: String
    /// What `fetch` returned, or why it did not.
    var fetched: Result<Data, Failure>
    /// What `fetchRaw` returned where `fetch` did not.
    var raw: Result<Data, Failure>?
  }

  struct Failure: Error, Sendable {
    var description: String
  }

  static func fetch(_ device: UnsafeMutablePointer<device_data_t>) -> [Resource] {
    paths.map { path in
      let fetched = attempt { try SuuntoNauticExplorer.fetch(device: device, path: path) }
      guard case .failure = fetched else { return Resource(path: path, fetched: fetched) }
      return Resource(
        path: path, fetched: fetched,
        raw: attempt { try SuuntoNauticExplorer.fetchRaw(device: device, path: path) })
    }
  }

  private static func attempt(_ body: () throws -> Data) -> Result<Data, Failure> {
    do {
      return .success(try body())
    } catch SuuntoNauticExplorer.ExplorerError.requestFailed(let status) {
      return .failure(Failure(description: LibDCNames.status(status)))
    } catch {
      return .failure(Failure(description: "\(error)"))
    }
  }
}
