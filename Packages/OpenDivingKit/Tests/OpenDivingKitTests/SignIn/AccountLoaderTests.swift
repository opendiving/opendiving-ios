import Foundation
import OpenDivingKit
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@MainActor
struct AccountLoaderTests {
  private let origin = ClientHarness.origin

  private func session(
    refreshToken: String?, transport: any HTTPTransport,
    secrets: [String: String] = [:]
  ) -> Session {
    Session(
      transport: transport,
      secrets: InMemorySecretStore(
        secrets.merging(refreshToken.map { [origin.description: $0] } ?? [:]) { $1 }),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      applicationSupport: FileManager.default.temporaryDirectory
        .appendingPathComponent("AccountLoaderTests-\(UUID().uuidString)", isDirectory: true),
      userAgent: ClientHarness.userAgent)
  }

  private static func accountRoutes() throws -> [String: StubTransport.Response] {
    [
      "POST auth/refresh": .refreshed(access: "fresh", refresh: "refresh-1"),
      "GET user": .json(try KitFixture.text("user")),
      "GET people": .json(try KitFixture.text("people-page")),
    ]
  }

  @Test func aColdStartSignedInRefreshesAndLoadsTheAccount() async throws {
    let transport = StubTransport(routes: try Self.accountRoutes())
    let session = session(refreshToken: "refresh-0", transport: transport)
    let loader = AccountLoader(session: session)
    await loader.launch()
    #expect(transport.requests.map(\.route) == ["POST auth/refresh", "GET user", "GET people"])
    #expect(session.user?.username == "testdiver")
    #expect(session.people.count == 3)
    #expect(loader.failure == nil)

    await loader.launch()
    #expect(transport.requests.count == 3)
  }

  @Test func aColdStartSignedOutLoadsNothing() async {
    let transport = StubTransport { _ in .unauthorized }
    let loader = AccountLoader(session: session(refreshToken: nil, transport: transport))
    await loader.launch()
    #expect(transport.requests.isEmpty)
  }

  @Test func aRefusedRefreshLandsOnSignInWithNothingToReport() async {
    let session = session(
      refreshToken: "refresh-0", transport: StubTransport { _ in .unauthorized })
    let loader = AccountLoader(session: session)
    await loader.launch()
    #expect(session.state == .signingIn(origin))
    #expect(loader.failure == nil)
  }

  @Test func aRefreshThatNeverArrivedKeepsTheSessionAndSaysSo() async throws {
    let session = session(
      refreshToken: "refresh-0", transport: StubTransport { _ in throw URLError(.timedOut) })
    let loader = AccountLoader(session: session)
    await loader.launch()
    #expect(session.state == .signedIn(origin))
    #expect(loader.failure != nil)
    loader.dismissFailure()
    #expect(loader.failure == nil)
  }

  @Test func aColdStartOnAServerThatNeverAnswersReportsNothingOnceLeft() async throws {
    let other = ServerOrigin("https://other.example.org")!
    let silent = SilentTransport()
    defer { silent.release() }
    let answering = StubTransport(routes: try Self.accountRoutes())
    let session = session(
      refreshToken: "refresh-0",
      transport: OneSilentServer(silentHost: origin.host, silent: silent, answering: answering),
      secrets: [other.description: "other-0"])
    let loader = AccountLoader(session: session)
    let launch = Task { await loader.launch() }
    while silent.requests.isEmpty { await Task.yield() }
    session.select(other)
    await launch.value
    await loader.sessionChanged(from: .signedIn(origin), to: session.state)
    #expect(session.user?.username == "testdiver")
    #expect(loader.failure == nil)
  }

  @Test func becomingSignedInLoadsTheAccount() async throws {
    let transport = StubTransport(routes: try Self.accountRoutes())
    let session = session(refreshToken: "refresh-0", transport: transport)
    let loader = AccountLoader(session: session)
    await loader.sessionChanged(from: .signingIn(origin), to: .signedIn(origin))
    #expect(session.user?.username == "testdiver")
    #expect(session.people.count == 3)

    let before = transport.requests.count
    await loader.sessionChanged(from: .signedIn(origin), to: .signingIn(origin))
    #expect(transport.requests.count == before)
  }
}

/// `silentHost` never answers; every other server answers from `answering`.
private struct OneSilentServer: HTTPTransport {
  let silentHost: String
  let silent: SilentTransport
  let answering: StubTransport

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    try await server(for: request).send(request)
  }

  func upload(_ request: URLRequest, fromFile file: URL) async throws -> (Data, HTTPURLResponse) {
    try await server(for: request).upload(request, fromFile: file)
  }

  private func server(for request: URLRequest) -> any HTTPTransport {
    request.url?.host == silentHost ? silent : answering
  }
}
