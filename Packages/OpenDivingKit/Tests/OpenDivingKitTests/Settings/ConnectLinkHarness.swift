import Foundation
import OpenDivingKit

/// A session signed in over a ``ConnectLinkServer``, its account read, in a directory of its
/// own.
@MainActor
struct ConnectLinkHarness {
  let server: ConnectLinkServer
  let connectivity: SettingsConnectivity
  /// Every write to the phone's keychain.
  let keychain: EventLog
  let secrets: LoggingSecretStore
  let directory: URL
  let session: Session

  init(linked: Bool = false, secrets kept: [String: String] = [:]) async throws {
    server = try ConnectLinkServer(linked: linked)
    connectivity = SettingsConnectivity()
    keychain = EventLog()
    directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("ConnectLinkTests-\(UUID().uuidString)", isDirectory: true)
    secrets = LoggingSecretStore(
      log: keychain,
      secrets: kept.merging([ClientHarness.origin.description: "refresh-0"]) { a, _ in a })
    session = Session(
      transport: server, secrets: secrets,
      activeOrigin: InMemoryActiveOriginStore(ClientHarness.origin),
      background: NoBackgroundExecution(), connectivity: connectivity,
      applicationSupport: directory, userAgent: ClientHarness.userAgent)
    try await session.loadAccount()
  }
}
