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
    #expect(model.card?.version == "Unknown")
    await model.load()
    // The fixture's build knows no commit, so the version stands alone.
    #expect(model.card?.version == "0.6.0")
  }

  @Test func aServerThatDoesNotAnswerLeavesTheVersionUnknown() async throws {
    let (model, _, session, _) = try signedIn([:])
    await model.load()
    #expect(model.card?.version == "Unknown")
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

  /// A model signed in to a server that never answers, waiting `wait` for a sign-out.
  private func signedInToASilentServer(wait: Duration) -> (
    SettingsModel, SignInFlow, Session, SilentTransport
  ) {
    let transport = SilentTransport()
    let session = Session(
      transport: transport, secrets: InMemorySecretStore([origin.description: "refresh-0"]),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      applicationSupport: FileManager.default.temporaryDirectory
        .appendingPathComponent("SettingsModelTests-\(UUID().uuidString)", isDirectory: true),
      userAgent: ClientHarness.userAgent)
    let flow = SignInFlow(session: session, signOutWait: wait)
    return (SettingsModel(session: session, signIn: flow), flow, session, transport)
  }

  @Test func aSignOutTheServerDoesNotAnswerGivesUpAndSaysSo() async throws {
    let (model, flow, session, transport) = signedInToASilentServer(wait: .milliseconds(50))
    defer { transport.release() }
    await model.signOut()
    #expect(model.error?.contains("did not answer, so you are still signed in") == true)
    #expect(session.state == .signedIn(origin))
    #expect(flow.signingOut == nil)
    #expect(!model.isWorking)
  }

  @Test func aTimedOutSignOutOffersForgettingOnlyWhereItCanBeDone() {
    #expect(SignOutResult.timedOut.failure(origin)?.contains("or forgetting this one") == true)
    #expect(
      SignOutResult.timedOut.failure(.flagship)
        == "\(ServerOrigin.flagship) did not answer, so you are still signed in. Changing server"
        + " does not need it to.")
  }

  @Test func stoppingTheWaitForASignOutKeepsTheSessionQuietly() async throws {
    let (model, flow, session, transport) = signedInToASilentServer(wait: .seconds(3600))
    defer { transport.release() }
    let signOut = Task { await model.signOut() }
    while flow.signingOut == nil { await Task.yield() }
    #expect(model.isWorking)
    flow.stopWaiting()
    await signOut.value
    #expect(model.error == nil)
    #expect(session.state == .signedIn(origin))
    #expect(!model.isWorking)
  }
}
