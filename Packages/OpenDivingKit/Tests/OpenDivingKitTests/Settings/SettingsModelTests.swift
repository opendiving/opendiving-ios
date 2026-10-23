import Foundation
import OpenDivingKit
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@MainActor
struct SettingsModelTests {
  private let origin = ClientHarness.origin

  private func signedIn(_ routes: [String: StubTransport.Response]) throws -> (
    SettingsModel, SignInFlow, Session, StubTransport
  ) {
    var routes = routes
    routes["POST auth/refresh"] =
      routes["POST auth/refresh"]
      ?? .refreshed(access: "fresh", refresh: "refresh-1")
    let transport = StubTransport(routes: routes)
    let session = Session(
      transport: transport, secrets: InMemorySecretStore([origin.description: "refresh-0"]),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      applicationSupport: FileManager.default.temporaryDirectory
        .appendingPathComponent("SettingsModelTests-\(UUID().uuidString)", isDirectory: true),
      userAgent: ClientHarness.userAgent)
    let flow = SignInFlow(session: session)
    return (SettingsModel(session: session, signIn: flow), flow, session, transport)
  }

  private static let loggedOut = StubTransport.Response.json(
    #"{"message":"Logged out successfully"}"#)

  @Test func afterAColdStartTheVersionIsUnknownUntilTheServerAnswers() async throws {
    let (model, _, session, _) = try signedIn([
      "GET config": .json(try KitFixture.text("config")),
      "GET health": .json(try KitFixture.text("health")),
    ])
    #expect(session.server == nil)
    #expect(model.serverVersion == "Unknown")
    await model.load()
    #expect(model.serverVersion == "0.6.0")
    #expect(model.serverCommit == "unknown")
  }

  @Test func aServerThatDoesNotAnswerLeavesTheVersionUnknown() async throws {
    let (model, _, session, _) = try signedIn([:])
    await model.load()
    #expect(model.serverVersion == "Unknown")
    #expect(session.state == .signedIn(origin))
  }

  @Test func unitsReadAsTheAccountHasThem() async throws {
    let user = try KitFixture.text("user")
    let imperial = user.replacingOccurrences(
      of: #""units": "metric""#, with: #""units": "imperial""#)
    #expect(imperial != user)
    let (model, _, session, _) = try signedIn([
      "GET user": .json(imperial),
      "GET people": .json(try KitFixture.text("people-page")),
    ])
    #expect(model.unitsLabel == "Metric")
    try await session.loadAccount()
    #expect(model.unitsLabel == "Imperial")
  }

  @Test func aFailedSignOutKeepsTheSessionAndSaysWhy() async throws {
    let (model, _, session, _) = try signedIn([
      "POST auth/logout": .json(#"{"detail":"Something broke"}"#, status: 500)
    ])
    await model.signOut()
    #expect(model.error == "Something broke")
    #expect(session.state == .signedIn(origin))
  }

  @Test func signingOutLandsSigningInToTheSameServer() async throws {
    let (model, flow, session, _) = try signedIn(["POST auth/logout": Self.loggedOut])
    await model.signOut()
    #expect(model.error == nil)
    #expect(session.state == .signingIn(origin))
    #expect(flow.step == .email)
  }

  @Test func changingServerSignsOutThenShowsTheServerScreen() async throws {
    let (model, flow, session, _) = try signedIn(["POST auth/logout": Self.loggedOut])
    let directory = session.store.directory(for: origin)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    await model.changeServer()
    #expect(session.state == .signingIn(origin))
    #expect(flow.step == .server)
    #expect(FileManager.default.fileExists(atPath: directory.path))
  }

  @Test func changingServerStaysWhenTheSignOutFails() async throws {
    let (model, flow, session, _) = try signedIn([
      "POST auth/logout": .json(#"{"detail":"Something broke"}"#, status: 500)
    ])
    await model.changeServer()
    #expect(session.state == .signedIn(origin))
    #expect(model.error == "Something broke")
    #expect(flow.step == .email)
  }

  @Test func aForgetThatFailsIsShownInSettings() async throws {
    let session = Session(
      transport: StubTransport(routes: [:]), secrets: RefusingSecretStore(),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      applicationSupport: FileManager.default.temporaryDirectory
        .appendingPathComponent("SettingsModelTests-\(UUID().uuidString)", isDirectory: true),
      userAgent: ClientHarness.userAgent)
    let flow = SignInFlow(session: session)
    let model = SettingsModel(session: session, signIn: flow)
    await model.forget()
    #expect(model.error?.contains("could not remove everything") == true)
    #expect(session.state == .signedIn(origin))
    #expect(flow.notice == nil)
  }

  @Test func forgettingAnOfflineServerRemovesItAnyway() async throws {
    let (model, flow, session, transport) = try signedIn([
      "POST auth/refresh": .json(#"{"detail":"Bad gateway"}"#, status: 502)
    ])
    await model.forget()
    #expect(transport.requests.map(\.route) == ["POST auth/refresh"])
    #expect(session.state == .noServer)
    #expect(!session.hasState(origin))
    #expect(flow.notice?.contains("Signing out on the server failed") == true)
  }
}

/// A Keychain holding a token it will not give up.
private final class RefusingSecretStore: SecretStore {
  struct Refused: Error {}

  func secret(for account: String) throws -> String? { "refresh-0" }
  func setSecret(_ value: String, for account: String) throws {}
  func removeSecret(for account: String) throws { throw Refused() }
}
