import Foundation
import OpenDivingKit

/// A session signed in over an ``InvitationsServer``, its account read, in a directory of its
/// own.
@MainActor
struct InvitationsHarness {
  let server: InvitationsServer
  let connectivity: SettingsConnectivity
  /// Every write to the phone's keychain.
  let keychain: EventLog
  let directory: URL
  let session: Session

  init(count: Int = 3, linked: Bool = false) async throws {
    server = try InvitationsServer(count: count, linked: linked)
    connectivity = SettingsConnectivity()
    keychain = EventLog()
    directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("InvitationsTests-\(UUID().uuidString)", isDirectory: true)
    session = Session(
      transport: server,
      secrets: LoggingSecretStore(
        log: keychain, secrets: [ClientHarness.origin.description: "refresh-0"]),
      activeOrigin: InMemoryActiveOriginStore(ClientHarness.origin),
      background: NoBackgroundExecution(), connectivity: connectivity,
      applicationSupport: directory, userAgent: ClientHarness.userAgent)
    try await session.loadAccount()
  }
}
