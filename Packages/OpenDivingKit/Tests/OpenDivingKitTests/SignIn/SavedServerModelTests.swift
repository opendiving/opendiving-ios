import Foundation
import OpenDivingKit
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@MainActor
struct SavedServerModelTests {
  private let origin = ClientHarness.origin
  private let other = ServerOrigin("https://other.example.org")!
  private let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("SavedServerModelTests-\(UUID().uuidString)", isDirectory: true)

  private static let loggedOut = StubTransport.Response.json(
    #"{"message":"Logged out successfully"}"#)

  private func session(
    _ routes: [String: StubTransport.Response], secrets: [String: String] = [:],
    now: @escaping () -> Date = { Date() }
  ) -> Session {
    Session(
      transport: StubTransport(routes: routes), secrets: InMemorySecretStore(secrets),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      applicationSupport: root, userAgent: ClientHarness.userAgent, now: now)
  }

  private static func health(commit: String) throws -> HealthRead {
    try APICoding.decoder().decode(
      HealthRead.self,
      from: Data(#"{"status":"healthy","version":"0.6.0","commit":"\#(commit)"}"#.utf8))
  }

  // MARK: - The card

  @Test func theCardPutsAShortCommitBesideTheVersion() throws {
    let known = ServerCardContent(
      origin: origin, health: try Self.health(commit: "1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b"))
    #expect(known.version == "0.6.0 (1a2b3c4)")
    #expect(known.address == origin.description)
    #expect(
      ServerCardContent(origin: origin, health: try Self.health(commit: "unknown")).version
        == "0.6.0")
    #expect(ServerCardContent(origin: origin, health: nil).version == "Unknown")
    #expect(!ServerCardContent(origin: ServerOrigin("http://10.0.0.2")!, health: nil).isEncrypted)
  }

  @Test func anotherServersPageAsksThatServerWhatItRuns() async throws {
    let session = session([
      "GET config": .json(try KitFixture.text("config")),
      "GET health": .json(try KitFixture.text("health")),
    ])
    let model = SavedServerModel(origin: other, signIn: SignInFlow(session: session))
    #expect(model.card.version == "Unknown")
    await model.load()
    #expect(model.card.version == "0.6.0")
    #expect(session.server == nil)
  }

  @Test func theLastVersionOutlivesARelaunchAndAFailedUpdate() async throws {
    let answering = session([
      "GET config": .json(try KitFixture.text("config")),
      "GET health": .json(try KitFixture.text("health")),
    ])
    await answering.loadServerInfo()
    #expect(answering.serverCard?.version == "0.6.0")
    let relaunched = session([:])
    #expect(relaunched.serverCard?.version == "0.6.0")
    await relaunched.loadServerInfo()
    #expect(relaunched.serverCard?.version == "0.6.0")
    #expect(relaunched.serverCard?.updateFailure != nil)
    try relaunched.forget(origin)
    #expect(relaunched.store.health(origin) == nil)
  }

  @Test func theCardSaysItIsUpdatingUntilTheServerAnswersOrFails() async {
    let transport = SilentTransport()
    defer { transport.release() }
    let session = Session(
      transport: transport, secrets: InMemorySecretStore([:]),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      applicationSupport: root, userAgent: ClientHarness.userAgent)
    let load = Task { await session.loadServerInfo() }
    while !session.validating.contains(origin) { await Task.yield() }
    #expect(session.serverCard?.isUpdating == true)
    #expect(session.serverCard?.version == "")
    #expect(session.serverCard?.updateFailure == nil)
    transport.release()
    await load.value
    #expect(session.serverCard?.isUpdating == false)
    #expect(session.serverCard?.version == "Unknown")
    #expect(session.serverCard?.updateFailure != nil)
  }

  @Test func anAnswerStandsForAMinuteAndIsThenAskedAgain() async throws {
    var clock = Date(timeIntervalSince1970: 1_798_000_000)
    let transport = StubTransport(routes: [
      "GET config": .json(try KitFixture.text("config")),
      "GET health": .json(try KitFixture.text("health")),
    ])
    let session = Session(
      transport: transport, secrets: InMemorySecretStore([:]),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      applicationSupport: root, userAgent: ClientHarness.userAgent, now: { clock })
    await session.loadServerInfo()
    clock += Session.serverInfoFreshness - 1
    await session.loadServerInfo()
    #expect(transport.requests.count == 2)
    clock += 1
    await session.loadServerInfo()
    #expect(transport.requests.count == 4)
  }

  // MARK: - The account and when it was used

  @Test func theActiveServerIsUsedNowAndAnotherWhenItWasLeft() {
    let left = Date(timeIntervalSince1970: 1_798_000_000)
    let session = session([:], now: { left })
    let flow = SignInFlow(session: session)
    session.select(other)
    let utc = TimeZone(identifier: "UTC")!
    #expect(SavedServerModel(origin: other, signIn: flow, timeZone: utc).lastUsed == "Now")
    #expect(
      SavedServerModel(origin: origin, signIn: flow, timeZone: utc).lastUsed
        == DateText.dateTime(left, in: utc))
    #expect(SavedServerModel(origin: .flagship, signIn: flow).lastUsed == "Unknown")
  }

  @Test func signedOutThereNamesNoAccountAndOffersNoSignOut() {
    let model = SavedServerModel(origin: origin, signIn: SignInFlow(session: session([:])))
    #expect(model.signedInAs == nil)
    #expect(!model.isSignedIn)
    #expect(model.canForget)
  }

  @Test func theFlagshipCannotBeForgotten() async {
    let model = SavedServerModel(origin: .flagship, signIn: SignInFlow(session: session([:])))
    #expect(!model.canForget)
    #expect(await !model.forget())
  }

  @Test func signingOutOfAnotherServerLeavesTheActiveOne() async {
    let session = session(
      [
        "POST auth/refresh": .refreshed(access: "fresh", refresh: "refresh-1"),
        "POST auth/logout": Self.loggedOut,
      ], secrets: [other.description: "refresh-0"])
    let model = SavedServerModel(origin: other, signIn: SignInFlow(session: session))
    #expect(model.signedInAs == "Account not loaded yet")
    await model.signOut()
    #expect(model.error == nil)
    #expect(!model.isSignedIn)
    #expect(session.state == .signingIn(origin))
  }

  // MARK: - Forgetting

  @Test func aForgetThatFailsIsShownOnThePage() async throws {
    let session = Session(
      transport: StubTransport(routes: [:]), secrets: RefusingSecretStore(),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      applicationSupport: root, userAgent: ClientHarness.userAgent)
    let flow = SignInFlow(session: session)
    let model = SavedServerModel(origin: origin, signIn: flow)
    #expect(await !model.forget())
    #expect(model.error?.contains("could not remove everything") == true)
    #expect(session.state == .signedIn(origin))
    #expect(flow.notice == nil)
  }

  @Test func aForgetThatSignedOutAndThenFailedIsLeftForTheSignInScreen() async throws {
    let session = Session(
      transport: StubTransport(routes: [
        "POST auth/refresh": .refreshed(access: "fresh", refresh: "refresh-1"),
        "POST auth/logout": Self.loggedOut,
      ]),
      secrets: RefusingSecretStore(),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      applicationSupport: root, userAgent: ClientHarness.userAgent)
    let flow = SignInFlow(session: session)
    #expect(await !SavedServerModel(origin: origin, signIn: flow).forget())
    // Signed out, the window shows the sign-in screen, not this page.
    #expect(session.state == .signingIn(origin))
    #expect(flow.notice?.contains("could not remove everything") == true)
  }

  @Test func forgettingAnOfflineServerRemovesItAnyway() async throws {
    let session = session(
      ["POST auth/refresh": .json(#"{"detail":"Bad gateway"}"#, status: 502)],
      secrets: [origin.description: "refresh-0"])
    let flow = SignInFlow(session: session)
    #expect(await SavedServerModel(origin: origin, signIn: flow).forget())
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
