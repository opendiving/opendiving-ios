import Foundation
import OpenDivingKit
import Testing

/// Signing in with a passkey: the button, the sheet on arrival, and the diver's own sign-out
/// that keeps the sheet down.
@MainActor
struct PasskeySignInTests {
  private let origin = ClientHarness.origin
  private let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("PasskeySignInTests-\(UUID().uuidString)", isDirectory: true)
  private let server: PasskeyServer
  private let ceremony = FakePasskeyCeremony()

  init() throws {
    server = try PasskeyServer()
  }

  /// Signing in to `origin`, or signed in with `refreshToken`, on a build associated with
  /// `host`; a nil `host` is a build with the association off.
  private func flow(host: String? = "dive.example.org", refreshToken: String? = nil)
    -> SignInFlow
  {
    let session = Session(
      transport: server,
      secrets: InMemorySecretStore(refreshToken.map { [origin.description: $0] } ?? [:]),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      applicationSupport: root, userAgent: ClientHarness.userAgent,
      passkeyAssociation: host.map { ceremony.association($0) })
    return SignInFlow(session: session, signOutWait: .seconds(5))
  }

  // MARK: - Where it is offered

  @Test func aBuildWithoutTheAssociationOffersNothingAndAsksNothing() async {
    let flow = flow(host: nil)
    #expect(!flow.offersPasskey)
    await flow.arriveAtEmail()
    await flow.signInWithPasskey()
    #expect(server.requests.isEmpty)
    #expect(ceremony.signIns.isEmpty)
  }

  @Test func aBuildForAnotherServerOffersNothing() async {
    let flow = flow(host: "opendiving.app")
    #expect(!flow.offersPasskey)
    await flow.arriveAtEmail()
    #expect(server.requests.isEmpty)
  }

  // MARK: - The button

  @Test func theButtonSignsInWithAnyPasskeyAndAsksForTheExtendedWindow() async throws {
    let flow = flow()
    #expect(flow.offersPasskey)
    await flow.signInWithPasskey()

    #expect(flow.session.state == .signedIn(origin))
    #expect(flow.session.signedInWith == .passkey)
    #expect(flow.passkeyError == nil)
    let request = try #require(ceremony.signIns.first)
    // The relying party the options name, not the server's address.
    #expect(request.relyingParty == "localhost")
    #expect(!request.onlyOnThisPhone)
    let sent = try #require(server.requests.first { $0.route == "POST auth/passkey/verify" }?.json)
    #expect(sent["flow_id"] == .string("ea599f0c-7b39-47d2-a84e-b3f33bc371d7"))
    #expect(sent["idle_timeout"] == .string("extended"))
    #expect(sent["credential"]?["authenticatorAttachment"] == .string("platform"))
  }

  @Test func anAccountScheduledForDeletionLeadsToTheRestore() async throws {
    server.answer(
      "POST auth/passkey/verify", with: .json(try KitFixture.text("auth-outcome-deletion-pending")))
    let flow = flow()
    await flow.signInWithPasskey()
    guard case .deletionPending(let email, _) = flow.step else {
      Issue.record("not the restore: \(flow.step)")
      return
    }
    #expect(email == "sam@example.com")
    #expect(flow.canRestore)
    #expect(flow.session.state == .signingIn(origin))
  }

  @Test func aDismissedSheetSaysNothing() async {
    ceremony.signInAnswer = .dismissed
    let flow = flow()
    await flow.signInWithPasskey()
    #expect(flow.passkeyError == nil)
    #expect(!flow.isSigningInWithPasskey)
    #expect(flow.session.state == .signingIn(origin))
    #expect(server.count("POST auth/passkey/verify") == 0)
  }

  @Test func theSystemsRefusalSaysTheWebsFallback() async {
    ceremony.signInAnswer = .failed
    let flow = flow()
    await flow.signInWithPasskey()
    #expect(flow.passkeyError == "Couldn't sign in with that passkey. Please try again.")
    #expect(!flow.isSigningInWithPasskey)
  }

  @Test func theAPIsRefusalSaysItsSentence() async {
    server.answer(
      "POST auth/passkey/verify",
      with: .json(#"{"detail":"That passkey could not be used to sign in."}"#, status: 401))
    let flow = flow()
    await flow.signInWithPasskey()
    #expect(flow.passkeyError == "That passkey could not be used to sign in.")
    #expect(flow.session.state == .signingIn(origin))
  }

  @Test func anInstanceWhosePasskeysAreUnavailableSaysSo() async {
    server.answer(
      "POST auth/passkey/options",
      with: .json(#"{"detail":"Passkey sign-in is unavailable. Use email."}"#, status: 503))
    let flow = flow()
    await flow.signInWithPasskey()
    #expect(flow.passkeyError == "Passkey sign-in is unavailable. Use email.")
    #expect(ceremony.signIns.isEmpty)
  }

  @Test func aRequestThatCouldNotBeSentSaysTheFallback() async {
    let session = Session(
      transport: StubTransport { _ in throw URLError(.notConnectedToInternet) },
      secrets: InMemorySecretStore(), activeOrigin: InMemoryActiveOriginStore(origin),
      background: NoBackgroundExecution(), applicationSupport: root,
      userAgent: ClientHarness.userAgent, passkeyAssociation: ceremony.association())
    let flow = SignInFlow(session: session)
    await flow.signInWithPasskey()
    #expect(flow.passkeyError == SignInFlow.passkeyFailed)
  }

  @Test func whileACeremonyIsOutNeitherButtonStartsAnything() async throws {
    ceremony.hold()
    let flow = flow()
    flow.setEmail("diver@example.com")
    let first = Task { await flow.signInWithPasskey() }
    while ceremony.signIns.isEmpty { await Task.yield() }
    #expect(flow.isSigningInWithPasskey)
    await flow.signInWithPasskey()
    await flow.sendCode()
    #expect(ceremony.signIns.count == 1)
    #expect(server.count("POST auth/email/request") == 0)
    ceremony.release()
    await first.value
    #expect(!flow.isSigningInWithPasskey)
  }

  // MARK: - The sheet on arrival

  @Test func onArrivalOnlyAPasskeyOnThePhoneIsAskedForOnceALaunch() async throws {
    ceremony.signInAnswer = .dismissed
    let flow = flow()
    await flow.arriveAtEmail()
    #expect(ceremony.signIns.map(\.onlyOnThisPhone) == [true])
    // The phone holds none: the system ends at once, and nothing is said.
    #expect(flow.passkeyError == nil)
    await flow.arriveAtEmail()
    #expect(server.count("POST auth/passkey/options") == 1)
  }

  @Test func onArrivalAPasskeyOnThePhoneSignsIn() async {
    let flow = flow()
    await flow.arriveAtEmail()
    #expect(flow.session.state == .signedIn(origin))
    #expect(flow.session.signedInWith == .passkey)
  }

  @Test func onArrivalNothingIsEverSaid() async {
    server.answer(
      "POST auth/passkey/verify",
      with: .json(#"{"detail":"That passkey could not be used to sign in."}"#, status: 401))
    let flow = flow()
    await flow.arriveAtEmail()
    #expect(flow.passkeyError == nil)
    #expect(flow.emailError == nil)
  }

  @Test func typingWhileTheOptionsAreAskedForDropsTheSheet() async {
    let gate = server.hold("POST auth/passkey/options")
    let flow = flow()
    let arrival = Task { await flow.arriveAtEmail() }
    await gate.untilArrived()
    flow.setEmail("d")
    await gate.open()
    await arrival.value
    #expect(ceremony.signIns.isEmpty)
    #expect(flow.email == "d")
    #expect(flow.session.state == .signingIn(origin))
  }

  @Test func aTapWhileTheSheetIsOutIgnoresItsAnswer() async {
    ceremony.hold()
    let flow = flow()
    let arrival = Task { await flow.arriveAtEmail() }
    while ceremony.signIns.isEmpty { await Task.yield() }
    flow.dropPasskeyArrival()
    #expect(ceremony.cancels == 1)
    ceremony.release()
    await arrival.value
    #expect(server.count("POST auth/passkey/verify") == 0)
    #expect(flow.session.state == .signingIn(origin))
  }

  @Test func theButtonReplacesTheSheetOnArrival() async {
    ceremony.hold()
    let flow = flow()
    let arrival = Task { await flow.arriveAtEmail() }
    while ceremony.signIns.isEmpty { await Task.yield() }
    let button = Task { await flow.signInWithPasskey() }
    while ceremony.signIns.count < 2 { await Task.yield() }
    #expect(ceremony.cancels == 1)
    #expect(ceremony.signIns.map(\.onlyOnThisPhone) == [true, false])
    ceremony.release()
    await arrival.value
    await button.value
    #expect(server.count("POST auth/passkey/verify") == 1)
    #expect(flow.session.state == .signedIn(origin))
  }

  @Test func noSheetWhileASignInLinkIsRedeemed() async {
    let gate = server.hold("POST auth/email/verify")
    let flow = flow()
    let link = Task { await flow.redeemLink("token") }
    await gate.untilArrived()
    await flow.arriveAtEmail()
    #expect(server.count("POST auth/passkey/options") == 0)
    await gate.open()
    await link.value
  }

  // MARK: - The diver's own sign-out

  @Test func aSignOutKeepsTheSheetDownUntilASignIn() async throws {
    let flow = flow(refreshToken: "refresh-0")
    try await flow.session.resume()
    #expect(await flow.signOut(of: origin) == .signedOut)
    #expect(flow.session.store.diverSignedOut(origin))

    await flow.arriveAtEmail()
    #expect(server.count("POST auth/passkey/options") == 0)

    // A relaunch: the mark is kept with the server.
    let relaunched = self.flow()
    await relaunched.arriveAtEmail()
    #expect(server.count("POST auth/passkey/options") == 0)

    // The button stays, and a sign-in by it clears the mark.
    await relaunched.signInWithPasskey()
    #expect(relaunched.session.state == .signedIn(origin))
    #expect(!relaunched.session.store.diverSignedOut(origin))
  }

  @Test func aSessionTheServerHadEndedCountsAsTheDiversSignOut() async throws {
    server.answer("POST auth/logout", with: .json(#"{"detail":"Not authenticated"}"#, status: 401))
    server.answer("POST auth/refresh", with: .json(#"{"detail":"Invalid"}"#, status: 401))
    let flow = flow(refreshToken: "refresh-0")
    #expect(await flow.signOut(of: origin) == .signedOut)
    #expect(flow.session.store.diverSignedOut(origin))
  }

  @Test func aSignOutThatFailedSetsNothing() async throws {
    server.answer("POST auth/logout", with: .json(#"{"detail":"Oops"}"#, status: 500))
    let flow = flow(refreshToken: "refresh-0")
    try await flow.session.resume()
    #expect(await flow.signOut(of: origin) == .failed("Oops"))
    #expect(!flow.session.store.diverSignedOut(origin))
  }

  @Test func aSessionEndedByTheServerIsNotASignOut() async throws {
    server.answer("POST auth/refresh", with: .json(#"{"detail":"Invalid"}"#, status: 401))
    let flow = flow(refreshToken: "refresh-0")
    await #expect(throws: APIError.signedOut) { try await flow.session.resume() }
    #expect(flow.session.state == .signingIn(origin))
    #expect(!flow.session.store.diverSignedOut(origin))
    await flow.arriveAtEmail()
    #expect(server.count("POST auth/passkey/options") == 1)
  }

  @Test func deletingTheAccountKeepsTheSheetDown() async throws {
    let flow = flow(refreshToken: "refresh-0")
    try await flow.session.resume()
    try await flow.deleteAccount()
    #expect(flow.session.store.diverSignedOut(origin))
  }

  @Test func forgettingTheServerForgetsTheMark() async throws {
    let flow = flow(refreshToken: "refresh-0")
    try await flow.session.resume()
    _ = await flow.signOut(of: origin)
    #expect(await flow.forget(origin) == nil)
    #expect(!flow.session.store.diverSignedOut(origin))
  }

  @Test func anEmailSignInIsNotAPasskeys() async throws {
    let flow = flow()
    server.answer(
      "POST auth/email/request",
      with: .json(#"{"message":"Check","request_id":"01a16586-8c04-7333-aa51-b37555e35546"}"#))
    flow.setEmail("diver@example.com")
    await flow.sendCode()
    flow.setCode("123456")
    await flow.submitCode()
    #expect(flow.session.state == .signedIn(origin))
    #expect(flow.session.signedInWith == .email)
  }
}
