import Foundation
import OpenDivingKit
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// *Delete my account*: the typed username, the archive first, and what the phone holds after.
@MainActor
struct AccountDeletionTests {
  private let origin = ClientHarness.origin
  private let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("AccountDeletionTests-\(UUID().uuidString)", isDirectory: true)

  private struct Signed {
    let session: Session
    let flow: SignInFlow
    let secrets: InMemorySecretStore
    let connectivity: SettingsConnectivity
  }

  private func signedIn(_ server: SettingsServer) async throws -> Signed {
    let secrets = InMemorySecretStore([origin.description: "refresh-0"])
    let connectivity = SettingsConnectivity()
    let session = Session(
      transport: server, secrets: secrets, activeOrigin: InMemoryActiveOriginStore(origin),
      background: NoBackgroundExecution(), connectivity: connectivity, applicationSupport: root,
      userAgent: ClientHarness.userAgent)
    try await session.loadAccount()
    return Signed(
      session: session, flow: SignInFlow(session: session), secrets: secrets,
      connectivity: connectivity)
  }

  private func exports() -> URL {
    root.appendingPathComponent("Exports", isDirectory: true)
  }

  @Test func theDeleteWaitsForTheUsernameTypedBackTrimmedAndWithoutCase() async throws {
    let signed = try await signedIn(try SettingsServer())
    let model = AccountDeletionModel(signIn: signed.flow)
    #expect(model.username == "testdiver")
    #expect(!model.canDelete)
    model.setTyped("testdive")
    #expect(!model.canDelete)
    model.setTyped("  TestDiver ")
    #expect(model.canDelete)
  }

  @Test func aDeletionEndsTheSessionKeepsTheServersDirectoryAndShowsTheGoodbye() async throws {
    let server = try SettingsServer()
    let signed = try await signedIn(server)
    let directory = signed.session.store.directory(for: origin)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let sheet = directory.appendingPathComponent("sheet.json")
    try Data("{}".utf8).write(to: sheet)
    let model = AccountDeletionModel(signIn: signed.flow)
    model.setTyped("testdiver")

    await model.delete()

    let delete = try #require(server.requests.last)
    #expect(delete.route == "DELETE user")
    // The cookie goes with it, so the server revokes the refresh token too.
    #expect(delete.cookie == "refresh_token=refresh-1")
    #expect(model.failure == nil)
    #expect(signed.session.state == .signingIn(origin))
    #expect(signed.session.user == nil)
    #expect(try signed.secrets.secret(for: origin.description) == nil)
    #expect(signed.session.store.rememberedUser(for: origin) == nil)
    #expect(FileManager.default.fileExists(atPath: sheet.path))
    #expect(signed.session.savedServers == [origin])
    // 2026-11-24T10:00:00Z is the 24th in every zone from UTC-10 to UTC+13.
    #expect(signed.flow.step == .accountDeleted(purgeAfter: "Nov 24, 2026"))
    signed.flow.useDifferentEmail()
    #expect(signed.flow.step == .email)
  }

  @Test func offlineNothingIsSentAndNothingChanges() async throws {
    let server = try SettingsServer()
    let signed = try await signedIn(server)
    signed.connectivity.isRouteAvailable = false
    let model = AccountDeletionModel(signIn: signed.flow)
    model.setTyped("testdiver")
    let before = server.requests.count

    await model.delete()

    #expect(server.requests.count == before)
    #expect(model.failure == APIError.noRoute.message)
    #expect(!model.isDeleting)
    #expect(signed.session.state == .signedIn(origin))
    #expect(try signed.secrets.secret(for: origin.description) == "refresh-1")
  }

  @Test func aRefusalIsTheAPIsSentenceAndChangesNothing() async throws {
    let server = try SettingsServer()
    let signed = try await signedIn(server)
    server.fail("DELETE user", with: .json(#"{"detail":"Too many requests."}"#, status: 429))
    let model = AccountDeletionModel(signIn: signed.flow)
    model.setTyped("testdiver")

    await model.delete()

    #expect(model.failure == "Too many requests.")
    #expect(model.canDelete)
    #expect(signed.session.state == .signedIn(origin))
    #expect(signed.session.user != nil)
  }

  @Test func theArchiveFirstHoldsTheDeleteUntilItsSheetCloses() async throws {
    let server = try SettingsServer()
    let signed = try await signedIn(server)
    let model = AccountDeletionModel(
      signIn: signed.flow, exports: DataExportModel(session: signed.session, directory: exports()))
    model.setTyped("testdiver")

    await model.exports.download(.archive)

    #expect(server.requests.last?.route == "GET export/archive")
    #expect(model.exports.shared != nil)
    #expect(!model.canDelete)
    await model.delete()
    #expect(server.requests.last?.route == "GET export/archive")
    model.exports.finishSharing()
    #expect(model.canDelete)
  }
}
