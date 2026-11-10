import Foundation
import OpenDivingKit

/// A session signed in over a ``CredentialsServer``, its account read, in a directory of its
/// own.
@MainActor
struct CredentialsHarness {
  let server: CredentialsServer
  let connectivity: SettingsConnectivity
  /// Every write to the phone's keychain.
  let keychain: EventLog
  let directory: URL
  let session: Session

  init() async throws {
    server = try CredentialsServer()
    connectivity = SettingsConnectivity()
    keychain = EventLog()
    directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("CredentialsTests-\(UUID().uuidString)", isDirectory: true)
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
