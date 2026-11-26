import Foundation
import OpenDivingKit
import Testing

/// *Sign in faster next time*: once to an account on this phone, after a sign-in it completed
/// in the app without a passkey.
@MainActor
struct PasskeyOfferModelTests {
  private let origin = ClientHarness.origin
  private let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("PasskeyOfferTests-\(UUID().uuidString)", isDirectory: true)
  private let server: PasskeyServer
  private let ceremony = FakePasskeyCeremony()

  init() throws {
    server = try PasskeyServer()
    server.answer("GET user/passkeys", with: .json("[]"))
    server.answer(
      "POST user/passkey/options", with: .json(try KitFixture.text("passkey-registration-options")))
    var added = StubTransport.Response.json(try KitFixture.text("passkey-added"))
    added.status = 201
    server.answer("POST user/passkey/verify", with: added)
    server.answer(
      "POST auth/email/request",
      with: .json(#"{"message":"Check","request_id":"01a16586-8c04-7333-aa51-b37555e35546"}"#))
  }

  private func session(host: String? = "dive.example.org", refreshToken: String? = nil) -> Session {
    Session(
      transport: server,
      secrets: InMemorySecretStore(refreshToken.map { [origin.description: $0] } ?? [:]),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      applicationSupport: root, userAgent: ClientHarness.userAgent,
      passkeyAssociation: host.map { ceremony.association($0) })
  }

  /// Signed in with the code, the account loaded.
  private func signedInWithTheCode(_ session: Session) async throws -> SignInFlow {
    let flow = SignInFlow(session: session)
    flow.setEmail("diver@example.com")
    await flow.sendCode()
    flow.setCode("123456")
    await flow.submitCode()
    try await session.loadAccount()
    return flow
  }

  @Test func anAccountWithNoneIsOfferedAfterTheCode() async throws {
    let session = session()
    _ = try await signedInWithTheCode(session)
    let offer = PasskeyOfferModel(session: session)
    await offer.check()
    #expect(offer.isOffered)
  }

  @Test func notNowIsTheAccountsAnswerOnThisPhone() async throws {
    let session = session()
    let flow = try await signedInWithTheCode(session)
    let offer = PasskeyOfferModel(session: session)
    await offer.check()
    offer.notNow()
    #expect(!offer.isOffered)
    let account = try #require(session.user?.uuid)
    #expect(session.store.answeredPasskeyOffer(for: origin, account: account))

    _ = await flow.signOut(of: origin)
    _ = try await signedInWithTheCode(session)
    await offer.check()
    #expect(!offer.isOffered)
  }

  @Test func aPasskeyAddedFromItAnswersIt() async throws {
    let session = session()
    _ = try await signedInWithTheCode(session)
    let offer = PasskeyOfferModel(session: session)
    await offer.check()
    await offer.add()
    #expect(!offer.isOffered)
    #expect(server.count("POST user/passkey/verify") == 1)
    let account = try #require(session.user?.uuid)
    #expect(session.store.answeredPasskeyOffer(for: origin, account: account))
  }

  @Test func aDismissalOrAFailureLeavesItOpen() async throws {
    let session = session()
    _ = try await signedInWithTheCode(session)
    let offer = PasskeyOfferModel(session: session)
    await offer.check()
    ceremony.registerAnswer = .dismissed
    await offer.add()
    #expect(offer.isOffered)
    #expect(offer.message == nil)
    ceremony.registerAnswer = .failed
    await offer.add()
    #expect(offer.isOffered)
    #expect(offer.message == PasskeyAdding.failed)
    ceremony.registerAnswer = .matchedExcludedCredential
    await offer.add()
    #expect(offer.message == PasskeyAdding.alreadyOnThisPhone)
  }

  @Test func closedAnyOtherWayItWasNotAnswered() async throws {
    let session = session()
    _ = try await signedInWithTheCode(session)
    let offer = PasskeyOfferModel(session: session)
    await offer.check()
    offer.close()
    let account = try #require(session.user?.uuid)
    #expect(!session.store.answeredPasskeyOffer(for: origin, account: account))
  }

  @Test func anAccountWithAPasskeyIsNotOffered() async throws {
    server.answer("GET user/passkeys", with: .json(try KitFixture.text("passkeys")))
    let session = session()
    _ = try await signedInWithTheCode(session)
    let offer = PasskeyOfferModel(session: session)
    await offer.check()
    #expect(!offer.isOffered)
  }

  @Test(arguments: [
    StubTransport.Response.json(#"{"detail":"Not Found"}"#, status: 404),
    StubTransport.Response.json(#"{"detail":"Oops"}"#, status: 500),
  ])
  func aListThatCannotBeReadMakesNoOffer(_ answer: StubTransport.Response) async throws {
    server.answer("GET user/passkeys", with: answer)
    let session = session()
    _ = try await signedInWithTheCode(session)
    let offer = PasskeyOfferModel(session: session)
    await offer.check()
    #expect(!offer.isOffered)
  }

  @Test func aLaunchThatFindsASessionIsNotASignIn() async throws {
    let session = session(refreshToken: "refresh-0")
    try await session.resume()
    let offer = PasskeyOfferModel(session: session)
    await offer.check()
    #expect(!offer.isOffered)
    #expect(server.count("GET user/passkeys") == 0)
  }

  @Test func aPasskeySignInIsNotOffered() async throws {
    let session = session()
    let flow = SignInFlow(session: session)
    await flow.signInWithPasskey()
    try await session.loadAccount()
    let offer = PasskeyOfferModel(session: session)
    await offer.check()
    #expect(!offer.isOffered)
  }

  @Test func aBuildWithoutTheAssociationOffersNothing() async throws {
    let session = session(host: nil)
    _ = try await signedInWithTheCode(session)
    let offer = PasskeyOfferModel(session: session)
    await offer.check()
    #expect(!offer.isOffered)
  }

  @Test func beforeTheAccountLoadsNothingIsOffered() async throws {
    let session = session()
    let flow = SignInFlow(session: session)
    flow.setEmail("diver@example.com")
    await flow.sendCode()
    flow.setCode("123456")
    await flow.submitCode()
    let offer = PasskeyOfferModel(session: session)
    await offer.check()
    #expect(!offer.isOffered)
  }
}
