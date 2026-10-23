import Foundation
import OpenDivingKit
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@MainActor
struct SignInFlowTests {
  private let origin = ServerOrigin("https://dive.example.org")!
  private let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("SignInFlowTests-\(UUID().uuidString)", isDirectory: true)
  private static let requestID = "01a16586-8c04-7333-aa51-b37555e35546"

  private func session(
    pointer: ServerOrigin?, secrets: [String: String] = [:], transport: StubTransport
  ) -> Session {
    Session(
      transport: transport, secrets: InMemorySecretStore(secrets),
      activeOrigin: InMemoryActiveOriginStore(pointer), background: NoBackgroundExecution(),
      applicationSupport: root, userAgent: ClientHarness.userAgent)
  }

  private static func failing(_ code: URLError.Code) -> StubTransport {
    StubTransport { _ in throw URLError(code) }
  }

  private static func codeRoutes(verify: StubTransport.Response) -> [String: StubTransport.Response]
  {
    [
      "POST auth/email/request": .json(
        #"{"message":"Check your email for the next step.","request_id":"\#(requestID)"}"#),
      "POST auth/email/verify-code": verify,
    ]
  }

  /// A flow at the code screen for `origin`.
  private func atTheCode(_ verify: StubTransport.Response) async -> (SignInFlow, Session) {
    let session = session(
      pointer: origin, transport: StubTransport(routes: Self.codeRoutes(verify: verify)))
    let flow = SignInFlow(session: session)
    flow.setEmail(" diver@example.com ")
    await flow.sendCode()
    return (flow, session)
  }

  // MARK: - Where the flow starts, and what it offers

  @Test func withNoServerItIsTheServerScreenPrefilledWithTheFlagship() {
    let flow = SignInFlow(
      session: session(pointer: nil, transport: Self.failing(.notConnectedToInternet)))
    #expect(flow.step == .server)
    #expect(flow.serverText == "https://opendiving.app")
    #expect(flow.signedOutEntries.isEmpty)
    #expect(!flow.canCancelServerChange)
  }

  @Test func signingInOffersExactlyTheSheetAnotherServerAndForgetting() {
    let flow = SignInFlow(
      session: session(pointer: origin, transport: Self.failing(.notConnectedToInternet)))
    #expect(flow.step == .email)
    #expect(flow.serverText == "https://dive.example.org")
    #expect(flow.signedOutEntries == [.checkInSheet, .differentServer, .forgetServer])
  }

  @Test func signedInOffersNothingSignedOut() {
    let flow = SignInFlow(
      session: session(
        pointer: origin, secrets: [origin.description: "refresh"],
        transport: Self.failing(.notConnectedToInternet)))
    #expect(flow.signedOutEntries.isEmpty)
  }

  // MARK: - The server screen

  @Test func aValidServerIsSelectedAndLeadsToTheEmail() async throws {
    let transport = StubTransport(routes: [
      "GET config": .json(try KitFixture.text("config")),
      "GET health": .json(try KitFixture.text("health")),
    ])
    let session = session(pointer: nil, transport: transport)
    let flow = SignInFlow(session: session)
    flow.setServerText("dive.example.org/dives")
    await flow.continueToServer()
    #expect(session.state == .signingIn(origin))
    #expect(session.server?.health?.version == "0.6.0")
    #expect(flow.step == .email)
    #expect(flow.serverText == "https://dive.example.org")
    #expect(flow.serverProblem == nil)
  }

  @Test func theThreeServerErrorsAreDistinct() async throws {
    let unreachable = SignInFlow(
      session: session(pointer: nil, transport: Self.failing(.cannotConnectToHost)))
    unreachable.setServerText("https://dive.example.org")
    await unreachable.continueToServer()

    let html = StubTransport { _ in
      StubTransport.Response(
        headers: ["Content-Type": "text/html"], body: Data("<html></html>".utf8))
    }
    let notAnInstance = SignInFlow(session: session(pointer: nil, transport: html))
    notAnInstance.setServerText("https://dive.example.org")
    await notAnInstance.continueToServer()

    let ats = SignInFlow(
      session: session(pointer: nil, transport: Self.failing(URLError.Code(rawValue: -1022))))
    ats.setServerText("http://dive.example.org")
    await ats.continueToServer()

    let problems = try [unreachable, notAnInstance, ats].map { try #require($0.serverProblem) }
    guard case .unreachable(_, localNetwork: false) = problems[0] else {
      Issue.record("Expected unreachable, got \(problems[0])")
      return
    }
    #expect(problems[1] == .notAnInstance)
    #expect(problems[2] == .refusedByATS)
    #expect(Set(problems.map(\.message)).count == 3)
    #expect(problems[2].message.contains(".local"))
    #expect(!problems[0].message.contains("Local Network"))
    for flow in [unreachable, notAnInstance, ats] {
      #expect(flow.step == .server)
    }
  }

  @Test func anUnreachableLocalServerPointsAtTheLocalNetworkSetting() async throws {
    let flow = SignInFlow(session: session(pointer: nil, transport: Self.failing(.timedOut)))
    flow.setServerText("http://192.168.1.20:8000")
    await flow.continueToServer()
    let problem = try #require(flow.serverProblem)
    guard case .unreachable(_, localNetwork: true) = problem else {
      Issue.record("Expected a local unreachable server, got \(problem)")
      return
    }
    #expect(problem.message.contains("Settings → Privacy & Security → Local Network"))
  }

  @Test func anUnreadableAddressIsSaidSoWithoutARequest() async {
    let transport = Self.failing(.cannotConnectToHost)
    let flow = SignInFlow(session: session(pointer: nil, transport: transport))
    flow.setServerText("mailto:diver@example.com")
    await flow.continueToServer()
    #expect(flow.serverProblem == .unreadableAddress)
    #expect(transport.requests.isEmpty)
  }

  @Test func aServerWithStateIsForgettableWhenItCannotBeReached() async throws {
    let gone = ServerOrigin("https://gone.example.org")!
    let flow = SignInFlow(
      session: session(
        pointer: nil, secrets: [gone.description: "refresh"],
        transport: Self.failing(.cannotFindHost)))
    flow.setServerText("https://gone.example.org")
    await flow.continueToServer()
    #expect(flow.serverProblem != nil)
    #expect(flow.forgettableOrigin == gone)

    flow.setServerText("https://dive.example.org")
    #expect(flow.forgettableOrigin == nil)
  }

  @Test func forgettingFromTheServerScreenNeedsNoServer() async throws {
    let gone = ServerOrigin("https://gone.example.org")!
    let transport = Self.failing(.cannotFindHost)
    let session = session(
      pointer: nil, secrets: [gone.description: "refresh"], transport: transport)
    let directory = session.store.directory(for: gone)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let flow = SignInFlow(session: session)
    flow.setServerText(gone.description)
    try await flow.forget(#require(flow.forgettableOrigin))
    #expect(!session.hasState(gone))
    #expect(flow.forgettableOrigin == nil)
    #expect(flow.notice?.contains("Removed everything") == true)
    #expect(transport.requests.isEmpty)
  }

  @Test func anotherServerAndBack() {
    let session = session(pointer: origin, transport: Self.failing(.notConnectedToInternet))
    let flow = SignInFlow(session: session)
    flow.useDifferentServer()
    #expect(flow.step == .server)
    #expect(flow.canCancelServerChange)
    flow.cancelServerChange()
    #expect(flow.step == .email)
    #expect(session.state == .signingIn(origin))
  }

  // MARK: - Forgetting the active server

  @Test func forgettingASignedInServerSignsOutFirst() async throws {
    let transport = StubTransport(routes: [
      "POST auth/refresh": .refreshed(access: "fresh", refresh: "refresh-1"),
      "POST auth/logout": .json(#"{"message":"Logged out successfully"}"#),
    ])
    let session = session(
      pointer: origin, secrets: [origin.description: "refresh-0"], transport: transport)
    let flow = SignInFlow(session: session)
    await flow.forget(origin)
    #expect(transport.requests.map(\.route).last == "POST auth/logout")
    #expect(session.state == .noServer)
    #expect(!session.hasState(origin))
    #expect(flow.step == .server)
    #expect(flow.serverText == "https://opendiving.app")
    #expect(flow.notice?.contains("failed") == false)
  }

  @Test func aFailedSignOutIsReportedAndForgettingGoesAhead() async throws {
    let session = session(
      pointer: origin, secrets: [origin.description: "refresh-0"],
      transport: Self.failing(.cannotFindHost))
    let directory = session.store.directory(for: origin)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let flow = SignInFlow(session: session)
    await flow.forget(origin)
    #expect(session.state == .noServer)
    #expect(!session.hasState(origin))
    #expect(flow.notice?.contains("Signing out on the server failed") == true)
  }

  @Test func aForgetThatCannotRemoveTheTokenSaysSoWhereItStarted() async {
    let session = Session(
      transport: Self.failing(.notConnectedToInternet), secrets: UnremovableSecretStore(),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      applicationSupport: root, userAgent: ClientHarness.userAgent)
    let flow = SignInFlow(session: session)
    #expect(await flow.forget(origin)?.contains("could not remove everything") == true)
    #expect(session.state == .signingIn(origin))
    #expect(flow.step == .email)
    #expect(flow.notice?.contains("could not remove everything") == true)
  }

  // MARK: - The email and the code

  @Test func anEmailLeadsToTheCode() async throws {
    let (flow, _) = await atTheCode(.json(try KitFixture.text("auth-outcome-authenticated")))
    #expect(
      flow.step
        == .code(email: "diver@example.com", requestID: UUID(uuidString: Self.requestID)!))
  }

  @Test func aRefusedEmailRequestShowsTheAPISentence() async {
    let transport = StubTransport(routes: [
      "POST auth/email/request": .json(
        #"{"detail":"Too many sign-in requests. Try again later."}"#, status: 429)
    ])
    let flow = SignInFlow(session: session(pointer: origin, transport: transport))
    flow.setEmail("diver@example.com")
    await flow.sendCode()
    #expect(flow.step == .email)
    #expect(flow.emailError == "Too many sign-in requests. Try again later.")
  }

  @Test func theCodeKeepsSixDigits() async throws {
    let (flow, _) = await atTheCode(.json(try KitFixture.text("auth-outcome-authenticated")))
    flow.setCode("12 a3-45678")
    #expect(flow.code == "123456")
    #expect(flow.isCodeComplete)
  }

  @Test func aShortCodeIsNotSent() async throws {
    let (flow, session) = await atTheCode(.json(try KitFixture.text("auth-outcome-authenticated")))
    flow.setCode("12345")
    await flow.submitCode()
    #expect(session.state == .signingIn(origin))
  }

  @Test func aWrongCodeShowsTheAPISentenceAndEmptiesTheField() async throws {
    let (flow, session) = await atTheCode(
      .json(#"{"detail":"This code is invalid or has expired."}"#, status: 401))
    flow.setCode("000000")
    await flow.submitCode()
    #expect(flow.codeError == "This code is invalid or has expired.")
    #expect(flow.code.isEmpty)
    #expect(session.state == .signingIn(origin))
    guard case .code = flow.step else {
      Issue.record("Expected the code screen, got \(flow.step)")
      return
    }
  }

  @Test func anUninvitedAddressShowsTheAPISentence() async throws {
    let sentence = "This email address has not been invited to this instance."
    let (flow, session) = await atTheCode(.json(#"{"detail":"\#(sentence)"}"#, status: 403))
    flow.setCode("123456")
    await flow.submitCode()
    #expect(flow.codeError == sentence)
    #expect(session.state == .signingIn(origin))
  }

  @Test func aCodeThatNeverArrivedDoesNotSayItWasWrong() async throws {
    let (flow, _) = await atTheCode(.json("", status: 500))
    flow.setCode("123456")
    await flow.submitCode()
    #expect(flow.codeError == "Couldn't check that code. Please try again.")
  }

  @Test func anAuthenticatedCodeSignsIn() async throws {
    let (flow, session) = await atTheCode(
      .json(
        try KitFixture.text("auth-outcome-authenticated"),
        headers: ["Set-Cookie": "refresh_token=fresh-cookie; HttpOnly; Path=/"]))
    flow.setCode("123456")
    await flow.submitCode()
    #expect(session.state == .signedIn(origin))
    #expect(flow.codeError == nil)
    #expect(flow.step == .email)
  }

  @Test func anUnfinishedAccountHasItsOwnScreen() async throws {
    let (flow, session) = await atTheCode(.json(try KitFixture.text("auth-outcome-onboarding")))
    flow.setCode("123456")
    await flow.submitCode()
    #expect(flow.step == .onboardingRequired(email: "sam@example.com", name: "Sam"))
    #expect(session.state == .signingIn(origin))
    flow.useDifferentEmail()
    #expect(flow.step == .email)
  }

  @Test func anAccountPendingDeletionHasItsOwnScreen() async throws {
    let (flow, session) = await atTheCode(
      .json(try KitFixture.text("auth-outcome-deletion-pending")))
    flow.setCode("123456")
    await flow.submitCode()
    guard case .deletionPending(let email, let purgeAfter) = flow.step else {
      Issue.record("Expected deletion pending, got \(flow.step)")
      return
    }
    #expect(email == "sam@example.com")
    // 2026-11-21T10:00:00Z is the 21st in every zone from UTC-10 to UTC+13.
    #expect(purgeAfter == "Nov 21, 2026")
    #expect(session.state == .signingIn(origin))
  }

  @Test func theOutcomeSentences() {
    let origin = ServerOrigin("https://opendiving.app")
    #expect(
      SignInFlow.onboardingMessage(email: "sam@example.com", origin: origin)
        == "The account for sam@example.com isn't finished yet. Sign-up is completed on the web,"
        + " at https://opendiving.app; then sign in here.")
    #expect(
      SignInFlow.onboardingMessage(email: nil, origin: nil)
        == "This account isn't finished yet. Sign-up is completed on the web, at this server;"
        + " then sign in here.")
    #expect(
      SignInFlow.deletionMessage(
        email: "sam@example.com", purgeAfter: "Nov 21, 2026", origin: origin)
        == "The account for sam@example.com is scheduled to be deleted after Nov 21, 2026. Until"
        + " then it can be restored on the web, at https://opendiving.app.")
    #expect(
      SignInFlow.deletionMessage(email: nil, purgeAfter: nil, origin: nil)
        == "This account is scheduled to be deleted. Until then it can be restored on the web,"
        + " at this server.")
  }

  @Test func resendWaitsThirtySeconds() async throws {
    let clock = TestClock(Date(timeIntervalSince1970: 1_000_000))
    let transport = StubTransport(
      routes: Self.codeRoutes(verify: .json(try KitFixture.text("auth-outcome-authenticated"))))
    let flow = SignInFlow(
      session: session(pointer: origin, transport: transport),
      now: { clock.date })
    flow.setEmail("diver@example.com")
    await flow.sendCode()
    let start = clock.date
    #expect(flow.resendSecondsLeft(at: start) == 30)
    #expect(flow.resendLabel(at: start.addingTimeInterval(4.5)) == "Resend code in 26s")

    await flow.resendCode()
    #expect(transport.requests.count == 1)

    clock.date = start.addingTimeInterval(30)
    #expect(flow.resendLabel(at: start.addingTimeInterval(30)) == "Resend code")
    await flow.resendCode()
    #expect(transport.requests.count == 2)
    #expect(flow.resendMessage != nil)
    #expect(flow.resendSecondsLeft(at: start.addingTimeInterval(30)) == 30)
  }
}

@MainActor
private final class TestClock {
  var date: Date

  init(_ date: Date) {
    self.date = date
  }
}

/// A Keychain whose items cannot be removed.
private final class UnremovableSecretStore: SecretStore {
  struct Refused: Error {}

  func secret(for account: String) throws -> String? { nil }
  func setSecret(_ value: String, for account: String) throws {}
  func removeSecret(for account: String) throws { throw Refused() }
}
