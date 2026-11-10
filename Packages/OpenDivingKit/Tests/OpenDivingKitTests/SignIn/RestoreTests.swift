import Foundation
import OpenDivingKit
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The deletion-pending outcome's *Restore*: what it sends, the session it starts, and the token
/// it holds in memory and nowhere else.
@MainActor
struct RestoreTests {
  private let origin = ServerOrigin("https://dive.example.org")!
  private let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("RestoreTests-\(UUID().uuidString)", isDirectory: true)
  private static let token = "restore-7f3a9c2e"
  private static let requestID = "01a16586-8c04-7333-aa51-b37555e35546"

  private static let pending = StubTransport.Response.json(
    #"{"status":"deletion_pending","access_token":null,"token_type":null,"#
      + #""onboarding_token":null,"name":null,"restore_token":"\#(token)","#
      + #""purge_after":"2026-11-24T10:00:00Z","email":"sam@example.com"}"#)

  private static let restored = StubTransport.Response.json(
    try! KitFixture.text("auth-outcome-authenticated"),
    headers: ["Set-Cookie": "refresh_token=restored-cookie; HttpOnly; Path=/; SameSite=lax"])

  private struct Flow {
    let flow: SignInFlow
    let session: Session
    let secrets: InMemorySecretStore
    let transport: StubTransport
  }

  /// A flow showing the deletion-pending outcome, its restore answering `restore`.
  private func atTheOffer(restore: StubTransport.Response = restored) async throws -> Flow {
    let transport = StubTransport(routes: [
      "POST auth/email/request": .json(
        #"{"message":"Check your email for the next step.","request_id":"\#(Self.requestID)"}"#),
      "POST auth/email/verify-code": Self.pending,
      "POST auth/restore": restore,
      "GET user": .json(try KitFixture.text("user")),
      "GET people": .json(try KitFixture.text("people-page")),
    ])
    let secrets = InMemorySecretStore()
    let session = Session(
      transport: transport, secrets: secrets, activeOrigin: InMemoryActiveOriginStore(origin),
      background: NoBackgroundExecution(), applicationSupport: root,
      userAgent: ClientHarness.userAgent)
    let flow = SignInFlow(session: session)
    flow.setEmail("sam@example.com")
    await flow.sendCode()
    flow.setCode("123456")
    await flow.submitCode()
    return Flow(flow: flow, session: session, secrets: secrets, transport: transport)
  }

  @Test func signingInIntoADeletedAccountOffersTheRestoreAndRestoresNothing() async throws {
    let at = try await atTheOffer()
    guard case .deletionPending(let email, let purgeAfter) = at.flow.step else {
      Issue.record("Expected deletion pending, got \(at.flow.step)")
      return
    }
    #expect(email == "sam@example.com")
    #expect(purgeAfter == "Nov 24, 2026")
    #expect(at.flow.canRestore)
    #expect(at.session.state == .signingIn(origin))
    #expect(!at.transport.requests.map(\.route).contains("POST auth/restore"))
  }

  @Test func theTokenIsWrittenNowhereAndPrintsRedacted() async throws {
    let at = try await atTheOffer()
    #expect(try at.secrets.secret(for: origin.description) == nil)
    let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
    while let file = files?.nextObject() as? URL {
      guard let data = try? Data(contentsOf: file) else { continue }
      #expect(!String(decoding: data, as: UTF8.self).contains(Self.token), "\(file.path)")
    }
    let outcome = try await Session(
      transport: StubTransport(routes: ["POST auth/email/verify-code": Self.pending]),
      secrets: InMemorySecretStore(), activeOrigin: InMemoryActiveOriginStore(origin),
      background: NoBackgroundExecution(), applicationSupport: root,
      userAgent: ClientHarness.userAgent
    ).verifyCode(requestID: UUID(), code: "123456")
    var dumped = ""
    dump(outcome, to: &dumped)
    for printed in [
      String(describing: outcome), String(reflecting: outcome), dumped,
      String(describing: at.flow.step),
    ] {
      #expect(!printed.contains(Self.token), "\(printed)")
    }
  }

  @Test func restoringSendsTheTokenAloneAndSignsInAsACodeDoes() async throws {
    let at = try await atTheOffer()

    await at.flow.restore()

    let request = try #require(at.transport.requests.last)
    #expect(request.route == "POST auth/restore")
    #expect(
      request.json == (try JSONValue.parse(Data(#"{"restore_token":"\#(Self.token)"}"#.utf8))))
    #expect(request.bearer == nil)
    #expect(at.session.state == .signedIn(origin))
    #expect(try at.secrets.secret(for: origin.description) == "restored-cookie")
    #expect(at.flow.step == .email)
    #expect(!at.flow.canRestore)
    try await at.session.loadAccount()
    #expect(at.transport.requests.last(where: { $0.route == "GET user" })?.bearer == "access-1")
    #expect(at.session.user?.username == "testdiver")
  }

  @Test func aRefusedRestoreIsTheAPIsSentenceAndKeepsTheOffer() async throws {
    let sentence = "This account has already been permanently deleted and cannot be restored."
    let at = try await atTheOffer(restore: .json(#"{"detail":"\#(sentence)"}"#, status: 401))

    await at.flow.restore()

    #expect(at.flow.restoreError == sentence)
    #expect(at.session.state == .signingIn(origin))
    #expect(try at.secrets.secret(for: origin.description) == nil)
    guard case .deletionPending = at.flow.step else {
      Issue.record("Expected deletion pending, got \(at.flow.step)")
      return
    }
  }

  @Test func leavingTheOfferDropsIt() async throws {
    let at = try await atTheOffer()
    at.flow.useDifferentEmail()
    #expect(!at.flow.canRestore)
    await at.flow.restore()
    #expect(!at.transport.requests.map(\.route).contains("POST auth/restore"))
  }
}
