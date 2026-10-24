import Foundation
import OpenDivingKit
import Synchronization
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The account's directory, the last-account pointer and `accountLoaded`.
@MainActor
struct SessionAccountTests {
  private let origin = ServerOrigin("https://dive.example.org")!
  private let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("SessionAccountTests-\(UUID().uuidString)", isDirectory: true)
  nonisolated private static let accountA = UUID(
    uuidString: "01a0a51f-afe3-7363-a0bc-b0d634c35923")!
  nonisolated private static let accountB = UUID(
    uuidString: "01a0a51f-afe3-7363-a0bc-b0d634c3592b")!

  /// The user fixture as account B, in imperial.
  nonisolated private static func userB() throws -> String {
    try KitFixture.text("user")
      .replacingOccurrences(
        of: accountA.uuidString.lowercased(), with: accountB.uuidString.lowercased()
      )
      .replacingOccurrences(of: #""units": "metric""#, with: #""units": "imperial""#)
  }

  /// Signs in by code as whoever `account` names at the time of the `GET user`.
  private final class Server: Sendable {
    final class Account: Sendable {
      private let name = Mutex("A")
      var current: String { name.withLock { $0 } }
      func become(_ new: String) { name.withLock { $0 = new } }
    }

    let account = Account()
    let transport: StubTransport

    init() throws {
      let a = try KitFixture.text("user")
      let b = try SessionAccountTests.userB()
      let people = try KitFixture.text("people-page")
      let outcome = try KitFixture.text("auth-outcome-authenticated")
      let account = account
      transport = StubTransport { request in
        switch request.route {
        case "POST auth/email/request":
          return .json(#"{"message":"Check your email.","request_id":"\#(UUID().uuidString)"}"#)
        case "POST auth/email/verify-code":
          return .json(outcome, headers: ["Set-Cookie": "refresh_token=fresh; Path=/"])
        case "GET user": return .json(account.current == "A" ? a : b)
        case "GET people": return .json(people)
        case "POST auth/logout": return .json(#"{"message":"Logged out successfully"}"#)
        default: return .json(#"{"detail":"Not Found"}"#, status: 404)
        }
      }
    }
  }

  private func session(_ transport: any HTTPTransport, token: String? = nil) -> Session {
    Session(
      transport: transport,
      secrets: InMemorySecretStore(token.map { [origin.description: $0] } ?? [:]),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      applicationSupport: root, userAgent: ClientHarness.userAgent)
  }

  private func signIn(_ session: Session) async throws {
    let request = try await session.requestCode(email: "diver@example.com")
    _ = try await session.verifyCode(requestID: request, code: "123456")
  }

  private func exists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path)
  }

  @Test func twoAccountsInTurnHaveTwoDirectoriesAndThePointerFollowsTheLatest() async throws {
    let server = try Server()
    let session = session(server.transport)
    let store = session.store
    try await signIn(session)
    #expect(store.lastAccount(for: origin) == nil)
    try await session.loadAccount()
    #expect(store.lastAccount(for: origin) == Self.accountA)
    #expect(
      store.formSettings(for: origin, account: Self.accountA)
        == AccountFormSettings(
          units: .metric, diveFormHiddenFields: try #require(session.user).diveFormHiddenFields))

    try await session.signOut()
    #expect(store.lastAccount(for: origin) == Self.accountA)
    #expect(store.formSettings(for: origin, account: Self.accountA) != nil)

    server.account.become("B")
    try await signIn(session)
    // Signed in, and still not known to be anyone else.
    #expect(store.lastAccount(for: origin) == Self.accountA)
    try await session.loadAccount()
    #expect(store.lastAccount(for: origin) == Self.accountB)
    #expect(store.formSettings(for: origin, account: Self.accountB)?.units == .imperial)
    #expect(store.formSettings(for: origin, account: Self.accountA)?.units == .metric)
    #expect(
      store.directory(for: origin, account: Self.accountA).deletingLastPathComponent()
        == store.directory(for: origin).appendingPathComponent("Accounts", isDirectory: true))
  }

  @Test func forgetRemovesEveryAccountsDirectoryAndThePointer() async throws {
    let server = try Server()
    let session = session(server.transport)
    try await signIn(session)
    try await session.loadAccount()
    try await session.signOut()
    server.account.become("B")
    try await signIn(session)
    try await session.loadAccount()
    let store = session.store
    #expect(exists(store.directory(for: origin, account: Self.accountA)))
    #expect(exists(store.directory(for: origin, account: Self.accountB)))
    try session.forget(origin)
    #expect(!exists(store.directory(for: origin, account: Self.accountA)))
    #expect(!exists(store.directory(for: origin, account: Self.accountB)))
    #expect(store.lastAccount(for: origin) == nil)
  }

  @Test func theAccountIsLoadedOnceTheLoadReturnsAndNoLongerAfterASignOut() async throws {
    let server = try Server()
    let session = session(server.transport)
    #expect(!session.accountLoaded)
    try await signIn(session)
    #expect(session.state == .signedIn(origin))
    #expect(!session.accountLoaded)
    try await session.loadAccount()
    #expect(session.accountLoaded)
    try await session.signOut()
    #expect(!session.accountLoaded)
  }

  @Test func aColdStartIsNotLoadedUntilItsResumeReturns() async throws {
    let routes: [String: StubTransport.Response] = [
      "POST auth/refresh": .refreshed(access: "fresh", refresh: "refresh-1"),
      "GET user": .json(try KitFixture.text("user")),
      "GET people": .json(try KitFixture.text("people-page")),
    ]
    let session = session(StubTransport(routes: routes), token: "refresh-0")
    #expect(session.state == .signedIn(origin))
    #expect(session.user == nil)
    #expect(!session.accountLoaded)
    try await session.resume()
    #expect(session.accountLoaded)
  }

  @Test func aLoadTheSessionEndedUnderStoresNothingAndLoadsNothing() async throws {
    let server = try Server()
    let gate = Gate()
    let session = session(HeldTransport(inner: server.transport, holding: "GET user", gate: gate))
    try await signIn(session)
    let load = Task { try await session.loadAccount() }
    await gate.untilArrived()
    try await session.signOut()
    await gate.open()
    // Its `GET people` finds no session to send with; either way, nothing lands.
    _ = try? await load.value
    #expect(!session.accountLoaded)
    #expect(session.user == nil)
    #expect(session.store.lastAccount(for: origin) == nil)
  }

  @Test func aLoadFromBeforeASignOutAndASignInDoesNotCountForTheNewSession() async throws {
    let server = try Server()
    let gate = Gate()
    let session = session(HeldTransport(inner: server.transport, holding: "GET user", gate: gate))
    try await signIn(session)
    let load = Task { try await session.loadAccount() }
    await gate.untilArrived()
    try await session.signOut()
    server.account.become("B")
    try await signIn(session)
    await gate.open()
    try await load.value
    // The held load read account A under the session that ended; the new one is B's.
    #expect(session.state == .signedIn(origin))
    #expect(!session.accountLoaded)
    #expect(session.store.lastAccount(for: origin) == nil)
  }

  @Test func theSeamsAreTheSessionsOwn() {
    let session = session(StubTransport { _ in .unauthorized })
    #expect(session.connectivity.isRouteAvailable)
    #expect(session.background is NoBackgroundExecution)
  }
}

/// Holds the first request to one route at a ``Gate``.
private final class HeldTransport: HTTPTransport {
  let inner: StubTransport
  private let route: String
  private let gate: Gate
  private let held = Mutex(false)

  init(inner: StubTransport, holding route: String, gate: Gate) {
    self.inner = inner
    self.route = route
    self.gate = gate
  }

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let hold =
      request.route == route
      && held.withLock { held in
        defer { held = true }
        return !held
      }
    if hold { await gate.pass() }
    return try await inner.send(request)
  }

  func upload(_ request: URLRequest, fromFile file: URL) async throws -> (Data, HTTPURLResponse) {
    try await inner.upload(request, fromFile: file)
  }
}
