import Foundation
import OpenDivingKit
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A sign-in link redeemed by the sign-in screens, the sign-up an address with no account is led
/// to, and a link held while the diver signs in.
@MainActor
struct SignInLinkTests {
  private let origin = ServerOrigin("https://dive.example.org")!
  private let other = ServerOrigin("https://other.example.org")!
  private let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("SignInLinkTests-\(UUID().uuidString)", isDirectory: true)
  private static let requestID = "01a16586-8c04-7333-aa51-b37555e35546"
  private static let dive = UUID(uuidString: "01a0e2ed-1be1-7142-996d-0639721e344d")!

  private func flow(_ routes: [String: StubTransport.Response]) -> (
    SignInFlow, Session, StubTransport
  ) {
    let transport = StubTransport(routes: routes)
    let session = Session(
      transport: transport, secrets: InMemorySecretStore([:]),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      applicationSupport: root, userAgent: ClientHarness.userAgent)
    return (SignInFlow(session: session), session, transport)
  }

  private static func outcome(_ fixture: String) throws -> StubTransport.Response {
    .json(
      try KitFixture.text(fixture),
      headers: ["Set-Cookie": "refresh_token=fresh-cookie; HttpOnly; Path=/"])
  }

  private static let emailRequest: StubTransport.Response = .json(
    #"{"message":"Check your email for the next step.","request_id":"\#(requestID)"}"#)

  private static func body(_ transport: StubTransport, _ route: String) -> JSONValue? {
    transport.requests.last { $0.route == route }?.json
  }

  // MARK: - Redeeming

  @Test func aSignInLinkSignsInAskingForTheExtendedWindow() async throws {
    let (flow, session, transport) = flow([
      "POST auth/email/verify": try Self.outcome("auth-outcome-authenticated")
    ])
    await flow.redeemLink("sign-in-link-token")
    #expect(session.state == .signedIn(origin))
    #expect(flow.step == .email)
    #expect(flow.linkError == nil)
    #expect(!flow.isRedeemingLink)
    #expect(
      Self.body(transport, "POST auth/email/verify")
        == (try JSONValue.parse(KitFixture.data("request-email-verify"))))
    #expect(transport.requests.first?.bearer == nil)
  }

  @Test func aRefusedLinkIsTheAPIsSentenceAndStaysSignedOut() async throws {
    let sentence = "This sign-in link has already been used."
    let (flow, session, _) = flow([
      "POST auth/email/verify": .json(#"{"detail":"\#(sentence)"}"#, status: 401)
    ])
    await flow.redeemLink("t")
    #expect(flow.linkError == sentence)
    #expect(session.state == .signingIn(origin))
    #expect(flow.step == .email)
    flow.dismissLinkError()
    #expect(flow.linkError == nil)
  }

  @Test func aLinkForAnAccountPendingDeletionOffersTheRestore() async throws {
    let (flow, session, _) = flow([
      "POST auth/email/verify": try Self.outcome("auth-outcome-deletion-pending")
    ])
    await flow.redeemLink("t")
    guard case .deletionPending(let email, _) = flow.step else {
      Issue.record("Expected deletion pending, got \(flow.step)")
      return
    }
    #expect(email == "sam@example.com")
    #expect(flow.canRestore)
    #expect(session.state == .signingIn(origin))
  }

  // MARK: - Signing up

  private func atTheSignUp(complete: StubTransport.Response) async throws -> (
    SignInFlow, Session, StubTransport
  ) {
    let (flow, session, transport) = flow([
      "POST auth/email/verify": try Self.outcome("auth-outcome-onboarding"),
      "POST auth/complete": complete,
    ])
    await flow.redeemLink("t")
    #expect(flow.step == .onboardingRequired(email: "sam@example.com", name: "Sam"))
    return (flow, session, transport)
  }

  @Test func aNewAccountIsCreatedAndSignedIn() async throws {
    let (flow, session, transport) = try await atTheSignUp(
      complete: try Self.outcome("auth-outcome-authenticated"))
    flow.setSignUpName(" Sam Diver ")
    flow.setSignUpUsername("samdiver")
    #expect(flow.canSignUp)
    await flow.signUp()
    #expect(session.state == .signedIn(origin))
    #expect(flow.step == .email)
    #expect(
      Self.body(transport, "POST auth/complete")
        == (try JSONValue.parse(KitFixture.data("request-profile-completion"))))
  }

  @Test func theFieldsAreHeldToTheAPIsBoundsBeforeAnythingIsSent() async throws {
    let (flow, _, transport) = try await atTheSignUp(complete: .json("{}", status: 500))
    flow.setSignUpUsername("")
    #expect(flow.signUpProblem(.username) == nil)
    #expect(!flow.canSignUp)
    flow.setSignUpName("S")
    #expect(flow.signUpProblem(.name) == "Name must be at least 2 characters")
    flow.setSignUpName(String(repeating: "a", count: 31))
    #expect(flow.signUpProblem(.name) == "Name cannot exceed 30 characters")
    flow.setSignUpName("Sam")
    #expect(flow.signUpProblem(.name) == nil)
    flow.setSignUpUsername("Sam")
    #expect(
      flow.signUpProblem(.username) == "Username can only contain lowercase letters and numbers")
    flow.setSignUpUsername(String(repeating: "a", count: 21))
    #expect(flow.signUpProblem(.username) == "Username cannot exceed 20 characters")
    #expect(!flow.canSignUp)
    await flow.signUp()
    #expect(!transport.requests.contains { $0.route == "POST auth/complete" })
  }

  @Test func aTakenUsernameOrTheGatesRefusalIsTheAPIsSentenceOnTheScreen() async throws {
    for (status, sentence) in [
      (422, "Username not available"),
      (403, "This email address has not been invited to this instance."),
    ] {
      let (flow, session, _) = try await atTheSignUp(
        complete: .json(#"{"detail":"\#(sentence)"}"#, status: status))
      flow.setSignUpUsername("robin")
      await flow.signUp()
      #expect(flow.signUpError == sentence)
      #expect(flow.step == .onboardingRequired(email: "sam@example.com", name: "Sam"))
      #expect(flow.signUpUsername == "robin")
      #expect(session.state == .signingIn(origin))
      flow.setSignUpUsername("robin2")
      #expect(flow.signUpError == nil)
    }
  }

  @Test func anExpiredOnboardingTokenLeadsBackToTheEmail() async throws {
    let sentence = "This onboarding session is invalid or has expired."
    let (flow, session, _) = try await atTheSignUp(
      complete: .json(#"{"detail":"\#(sentence)"}"#, status: 401))
    flow.setSignUpUsername("samdiver")
    await flow.signUp()
    #expect(flow.step == .email)
    #expect(flow.email == "sam@example.com")
    #expect(flow.emailError == sentence)
    #expect(session.state == .signingIn(origin))
  }

  @Test func theTermsLinkTheServersPages() {
    let terms = SignInFlow.signUpTerms(origin)
    #expect(
      terms.map(\.text).joined()
        == "By creating an account, you agree to our Terms of Service and Privacy Policy")
    #expect(
      terms.compactMap(\.url).map(\.absoluteString)
        == ["https://dive.example.org/terms", "https://dive.example.org/privacy"])
  }

  // MARK: - A held link

  @Test func aHeldRecordOpensOnceSignedInOnItsServer() async throws {
    let (flow, _, transport) = flow([:])
    await flow.hold(.record(.dive(Self.dive)))
    #expect(flow.invitation == nil)
    #expect(transport.requests.isEmpty)
    #expect(flow.takeHeldScreen(.signingIn(origin)) == nil)
    #expect(flow.takeHeldScreen(.signedIn(origin)) == .record(.dive(Self.dive)))
    #expect(flow.takeHeldScreen(.signedIn(origin)) == nil)
  }

  @Test func anotherServerDropsWhatIsHeld() async throws {
    let (flow, _, _) = flow([:])
    await flow.hold(.record(.dive(Self.dive)))
    #expect(flow.takeHeldScreen(.signingIn(other)) == nil)
    #expect(flow.takeHeldScreen(.signedIn(origin)) == nil)
    await flow.hold(.record(.dive(Self.dive)))
    #expect(flow.takeHeldScreen(.noServer) == nil)
    #expect(flow.takeHeldScreen(.signedIn(origin)) == nil)
  }

  @Test func aHeldConnectLinkSaysWhoseItIsAndGoesWithTheEmail() async throws {
    let (flow, _, transport) = flow([
      "GET connect-link/abc": .json(try KitFixture.text("connect-link-owner-signed-out")),
      "POST auth/email/request": Self.emailRequest,
    ])
    await flow.hold(.connect(token: "abc"))
    #expect(
      flow.invitation
        == .from(
          name: "Robin Diver",
          picture: ConnectedPicture(source: .connectLink("abc"), version: "cd34")))
    #expect(transport.requests.first?.bearer == nil)
    flow.setEmail("new@example.com")
    await flow.sendCode()
    #expect(
      Self.body(transport, "POST auth/email/request")
        == .object(["email": .string("new@example.com"), "via": .string("abc")]))
    #expect(flow.takeHeldScreen(.signedIn(origin)) == .connect(token: "abc"))
    #expect(flow.invitation == nil)
  }

  @Test func aConnectLinkNoLongerActiveIsSaidToBeAndDropped() async throws {
    let (flow, _, transport) = flow([
      "GET connect-link/abc": .json(#"{"detail":"No such connect link."}"#, status: 404),
      "POST auth/email/request": Self.emailRequest,
    ])
    await flow.hold(.connect(token: "abc"))
    #expect(flow.invitation == .gone)
    flow.setEmail("new@example.com")
    await flow.sendCode()
    #expect(
      Self.body(transport, "POST auth/email/request")
        == .object(["email": .string("new@example.com")]))
    #expect(flow.takeHeldScreen(.signedIn(origin)) == nil)
    #expect(flow.invitation == nil)
  }

  @Test func aConnectLinkWhoseReadFailsIsStillHeld() async throws {
    let reply = Self.emailRequest
    let transport = StubTransport { request in
      guard request.route == "POST auth/email/request" else { throw URLError(.timedOut) }
      return reply
    }
    let session = Session(
      transport: transport, secrets: InMemorySecretStore([:]),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      applicationSupport: root, userAgent: ClientHarness.userAgent)
    let flow = SignInFlow(session: session)
    await flow.hold(.connect(token: "abc"))
    #expect(flow.invitation == .reading)
    flow.setEmail("new@example.com")
    await flow.sendCode()
    #expect(
      Self.body(transport, "POST auth/email/request")
        == .object(["email": .string("new@example.com"), "via": .string("abc")]))
  }

  @Test func theInvitationInTheWebsWords() {
    #expect(SignInFlow.invitationTitle("Robin") == "Robin invited you to connect on OpenDiving")
    let (flow, _, _) = flow([:])
    #expect(
      flow.invitationNote("Robin")
        == "Enter your email to sign in, or to create your account. A new account starts with"
        + " Robin in its people, and Robin sees its name, username and picture.")
  }
}
