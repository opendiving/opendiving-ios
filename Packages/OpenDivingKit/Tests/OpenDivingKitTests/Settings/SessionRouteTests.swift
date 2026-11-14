import Foundation
import OpenDivingKit
import Testing

/// What the screens offer follows the route: lost and found again.
@MainActor
struct SessionRouteTests {
  @Test func hasRouteFollowsTheRouteBothWays() async throws {
    let connectivity = SettingsConnectivity(available: false)
    let session = Session(
      transport: try SettingsServer(), secrets: InMemorySecretStore(),
      activeOrigin: InMemoryActiveOriginStore(ClientHarness.origin),
      background: NoBackgroundExecution(), connectivity: connectivity,
      applicationSupport: FileManager.default.temporaryDirectory
        .appendingPathComponent("SessionRouteTests-\(UUID().uuidString)", isDirectory: true),
      userAgent: ClientHarness.userAgent)
    #expect(!session.hasRoute)

    let following = Task { await session.followRouteChanges() }
    while !connectivity.isRouteFollowed { await Task.yield() }
    connectivity.appear()
    while !session.hasRoute { await Task.yield() }
    connectivity.isRouteAvailable = false
    while session.hasRoute { await Task.yield() }
    following.cancel()
  }
}
