import Foundation

/// The `URLSessionConfiguration` the Kit's client is built over. Built here rather than in the
/// Kit because `waitsForConnectivity` does not exist in Linux's Foundation.
nonisolated enum NetworkConfiguration {
  /// How long a request may wait for a route before it fails as unreachable.
  static let resourceTimeout: TimeInterval = 60

  /// Waits for connectivity, so that a request to a local-network server made while the Local
  /// Network prompt is up waits for the answer instead of failing before it; a refused
  /// connection still fails at once. The Kit switches off the cookie jar and the cache.
  static func make() -> URLSessionConfiguration {
    let configuration = URLSessionConfiguration.default
    configuration.waitsForConnectivity = true
    configuration.timeoutIntervalForResource = resourceTimeout
    return configuration
  }
}
