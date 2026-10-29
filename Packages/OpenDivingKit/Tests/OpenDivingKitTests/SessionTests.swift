import Foundation
import OpenDivingKit
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@MainActor
struct SessionTests {
  private let origin = ServerOrigin("https://dive.example.org")!
  private let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("SessionTests-\(UUID().uuidString)", isDirectory: true)

  private func session(
    pointer: ServerOrigin?, refreshToken: String?,
    transport: StubTransport = StubTransport { _ in
      .unauthorized
    }
  ) -> (Session, InMemorySecretStore, InMemoryActiveOriginStore) {
    let secrets = InMemorySecretStore(refreshToken.map { [origin.description: $0] } ?? [:])
    let pointerStore = InMemoryActiveOriginStore(pointer)
    let session = Session(
      transport: transport, secrets: secrets, activeOrigin: pointerStore,
      background: NoBackgroundExecution(), applicationSupport: root,
      userAgent: ClientHarness.userAgent)
    return (session, secrets, pointerStore)
  }

  private static func accountRoutes() throws -> [String: StubTransport.Response] {
    [
      "POST auth/refresh": .refreshed(access: "fresh", refresh: "refresh-1"),
      "GET user": .json(try KitFixture.text("user")),
      "GET people": .json(try KitFixture.text("people-page")),
      "POST auth/logout": .json(#"{"message":"Logged out successfully"}"#),
    ]
  }

  @Test func aColdStartWithNoPointerHasNoServer() {
    let (session, _, _) = session(pointer: nil, refreshToken: "refresh-0")
    #expect(session.state == .noServer)
    #expect(session.client == nil)
  }

  @Test func aColdStartWithAPointerAndNoTokenIsSigningIn() {
    let (session, _, _) = session(pointer: origin, refreshToken: nil)
    #expect(session.state == .signingIn(origin))
    #expect(session.client?.origin == origin)
  }

  @Test func aColdStartWithAPointerAndATokenIsSignedInAndResumes() async throws {
    let transport = StubTransport(routes: try Self.accountRoutes())
    let (session, secrets, _) = session(
      pointer: origin, refreshToken: "refresh-0", transport: transport)
    #expect(session.state == .signedIn(origin))
    try await session.resume()
    #expect(session.user?.username == "testdiver")
    #expect(session.people.count == 3)
    #expect(try secrets.secret(for: origin.description) == "refresh-1")
    #expect(transport.requests.map(\.route) == ["POST auth/refresh", "GET user", "GET people"])
  }

  @Test func aRelaunchRemembersTheAccount() async throws {
    let transport = StubTransport(routes: try Self.accountRoutes())
    let (first, _, _) = session(pointer: origin, refreshToken: "refresh-0", transport: transport)
    try await first.resume()
    let (second, _, _) = session(pointer: origin, refreshToken: "refresh-1")
    #expect(second.user?.username == "testdiver")
  }

  @Test func aRefusedRefreshSignsOutAndKeepsThePointer() async throws {
    let (session, secrets, pointer) = session(pointer: origin, refreshToken: "refresh-0")
    await #expect(throws: APIError.signedOut) { try await session.resume() }
    #expect(session.state == .signingIn(origin))
    #expect(try secrets.secret(for: origin.description) == nil)
    #expect(pointer.load() == origin)
  }

  @Test func signingInWithACode() async throws {
    var routes = try Self.accountRoutes()
    routes["POST auth/email/request"] = .json(
      #"{"message":"Check your email for the next step.","#
        + #""request_id":"01a16586-8c04-7333-aa51-b37555e35546"}"#)
    routes["POST auth/email/verify-code"] = .json(
      try KitFixture.text("auth-outcome-authenticated"),
      headers: ["Set-Cookie": "refresh_token=fresh-cookie; HttpOnly; Path=/"])
    let (session, secrets, pointer) = session(
      pointer: nil, refreshToken: nil, transport: StubTransport(routes: routes))
    session.select(origin)
    #expect(session.state == .signingIn(origin))
    #expect(pointer.load() == origin)
    let requestID = try await session.requestCode(email: "diver@example.com")
    #expect(try await session.verifyCode(requestID: requestID, code: "123456") == .signedIn)
    #expect(session.state == .signedIn(origin))
    #expect(try secrets.secret(for: origin.description) == "fresh-cookie")
    try await session.loadAccount()
    #expect(
      session.person(UUID(uuidString: "01a0e2ed-1be1-7142-996d-0639721e344d")!)?.name == "Ana Diaz")
  }

  @Test func theOutcomesThatAreNotASignIn() async throws {
    let (session, _, _) = session(
      pointer: origin, refreshToken: nil,
      transport: StubTransport { request in
        .json(
          try KitFixture.text(
            request.httpBody.map { String(decoding: $0, as: UTF8.self) }?.contains("111111") == true
              ? "auth-outcome-onboarding" : "auth-outcome-deletion-pending"))
      })
    #expect(
      try await session.verifyCode(requestID: UUID(), code: "111111")
        == .onboardingRequired(email: "sam@example.com", name: "Sam"))
    guard
      case .deletionPending(let email, let purgeAfter) = try await session.verifyCode(
        requestID: UUID(), code: "222222")
    else {
      Issue.record("Expected deletion pending")
      return
    }
    #expect(email == "sam@example.com")
    #expect(purgeAfter != nil)
    #expect(session.state == .signingIn(origin))
  }

  @Test func signingOutKeepsTheDirectoryAndThePointer() async throws {
    let (session, secrets, pointer) = session(
      pointer: origin, refreshToken: "refresh-0",
      transport: StubTransport(routes: try Self.accountRoutes()))
    try await session.resume()
    let sheet = try writeFileIntoTheServerDirectory(session)
    try await session.signOut()
    #expect(session.state == .signingIn(origin))
    #expect(session.user == nil)
    #expect(try secrets.secret(for: origin.description) == nil)
    #expect(session.store.rememberedUser(for: origin) == nil)
    #expect(FileManager.default.fileExists(atPath: sheet.path))
    #expect(pointer.load() == origin)
    #expect(session.hasState(origin))
  }

  @Test func forgetRemovesTheTokenTheAccountAndTheDirectory() async throws {
    let (session, secrets, pointer) = session(
      pointer: origin, refreshToken: "refresh-0",
      transport: StubTransport(routes: try Self.accountRoutes()))
    try await session.resume()
    let sheet = try writeFileIntoTheServerDirectory(session)
    #expect(session.hasState(origin))
    try session.forget(origin)
    #expect(try secrets.secret(for: origin.description) == nil)
    #expect(session.store.rememberedUser(for: origin) == nil)
    #expect(!FileManager.default.fileExists(atPath: sheet.deletingLastPathComponent().path))
    #expect(!session.hasState(origin))
    #expect(pointer.load() == nil)
    #expect(session.state == .noServer)
  }

  @Test func forgettingAnotherServerLeavesTheActiveOneAlone() throws {
    let other = ServerOrigin("http://192.168.1.20:8000")!
    let (session, secrets, pointer) = session(pointer: origin, refreshToken: "refresh-0")
    try secrets.setSecret("other-token", for: other.description)
    #expect(session.hasState(other))
    try session.forget(other)
    #expect(!session.hasState(other))
    #expect(pointer.load() == origin)
    #expect(session.state == .signedIn(origin))
  }

  @Test func everyServerChosenIsSavedUntilItIsForgotten() throws {
    let other = ServerOrigin("https://other.example.org")!
    let (session, _, _) = session(pointer: origin, refreshToken: nil)
    #expect(session.savedServers == [origin])
    session.select(other)
    session.select(origin)
    #expect(session.savedServers == [origin, other])
    let (relaunched, _, _) = self.session(pointer: other, refreshToken: nil)
    #expect(relaunched.savedServers == [origin, other])
    try relaunched.forget(origin)
    #expect(relaunched.savedServers == [other])
    #expect(!relaunched.hasState(origin))
  }

  @Test func choosingAnotherServerKeepsTheSessionOnTheOneLeft() throws {
    let other = ServerOrigin("https://other.example.org")!
    let (session, secrets, _) = session(pointer: origin, refreshToken: "refresh-0")
    session.select(other)
    #expect(session.state == .signingIn(other))
    #expect(session.isSignedIn(to: origin))
    #expect(try secrets.secret(for: origin.description) == "refresh-0")
    session.select(origin)
    #expect(session.state == .signedIn(origin))
  }

  @Test func signingOutOfAnotherServerUsesItsOwnSession() async throws {
    let other = ServerOrigin("https://other.example.org")!
    let transport = StubTransport(routes: try Self.accountRoutes())
    let (session, secrets, _) = session(
      pointer: origin, refreshToken: "refresh-0", transport: transport)
    session.select(other)
    try await session.signOut(of: origin)
    #expect(transport.requests.map(\.route) == ["POST auth/refresh", "POST auth/logout"])
    #expect(transport.requests.allSatisfy { $0.url?.host == "dive.example.org" })
    #expect(try secrets.secret(for: origin.description) == nil)
    #expect(session.state == .signingIn(other))
  }

  @Test func aServerWithNothingStoredHasNoState() {
    let (session, _, _) = session(pointer: nil, refreshToken: nil)
    #expect(!session.hasState(origin))
  }

  @Test func theStubFactoryIsSignedInOverItsTransport() async throws {
    let session = Session.stub(transport: StubTransport(routes: try Self.accountRoutes()))
    #expect(session.state.origin != nil)
    try await session.loadAccount()
    #expect(session.units == .metric)
    #expect(session.people.count == 3)
  }

  private func writeFileIntoTheServerDirectory(_ session: Session) throws -> URL {
    let directory = session.store.directory(for: origin)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("sheet.json")
    try Data("{}".utf8).write(to: file)
    return file
  }
}
