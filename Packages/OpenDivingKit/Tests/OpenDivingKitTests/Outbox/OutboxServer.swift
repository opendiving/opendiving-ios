import Foundation
import Synchronization

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A server for the queue's tests: it signs in as account A or B, creates what it is sent
/// under fresh uuids and reads back what it created, keeps every request, and answers any
/// route the test chooses its own way first.
final class OutboxServer: HTTPTransport {
  static let origin = ServerOrigin("https://dive.example.org")!
  static let accountA = UUID(uuidString: "01a0a51f-afe3-7363-a0bc-b0d634c35923")!
  static let accountB = UUID(uuidString: "01a0a51f-afe3-7363-a0bc-b0d634c3592b")!

  /// Answers a request before the default does; nil leaves it to the default. `index` counts
  /// the requests to the same route before this one.
  typealias Override = @Sendable (_ request: URLRequest, _ index: Int) async throws ->
    StubTransport.Response?

  struct Sent: Sendable {
    let route: String
    let body: Data?
    let key: String?

    var json: [String: Any] {
      body.flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? [String: Any] } ?? [:]
    }
  }

  private struct State {
    var account = OutboxServer.accountA
    var sent: [Sent] = []
    var created: [UUID] = []
    var override: Override?
    var drafts = "[]"
  }

  private let state = Mutex(State())
  private let fixtures: [String: String]

  init() throws {
    var fixtures: [String: String] = [:]
    for name in [
      "user", "people-page", "dive-detail", "dive-site", "trip", "course", "contact",
      "gear-item", "dive-draft", "gear-sets-page", "dives-page",
    ] {
      fixtures[name] = try KitFixture.text(name)
    }
    self.fixtures = fixtures
  }

  func signIn(as account: UUID) { state.withLock { $0.account = account } }
  func override(_ answer: @escaping Override) { state.withLock { $0.override = answer } }
  /// What `GET dive-drafts` answers: the rows as a JSON array.
  func answerDrafts(_ rows: String) { state.withLock { $0.drafts = rows } }

  var sent: [Sent] { state.withLock { $0.sent } }
  var routes: [String] { sent.map(\.route) }
  /// The requests that write, in order.
  var writes: [Sent] { sent.filter { !$0.route.hasPrefix("GET ") } }
  var created: [UUID] { state.withLock { $0.created } }

  func count(_ route: String, since mark: Int = 0) -> Int {
    routes.dropFirst(mark).filter { $0 == route }.count
  }

  /// The writes sent after the first `mark` requests.
  func writes(since mark: Int) -> [Sent] {
    sent.dropFirst(mark).filter { !$0.route.hasPrefix("GET ") }
  }

  /// Where the requests stand now, for ``writes(since:)``.
  var mark: Int { sent.count }

  func upload(_ request: URLRequest, fromFile file: URL) async throws -> (Data, HTTPURLResponse) {
    var request = request
    request.httpBody = try Data(contentsOf: file)
    return try await send(request)
  }

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let route = request.route
    let (index, override) = state.withLock { state in
      let index = state.sent.filter { $0.route == route }.count
      state.sent.append(Sent(route: route, body: request.httpBody, key: request.idempotencyKey))
      return (index, state.override)
    }
    let response = try await override?(request, index) ?? answer(route)
    let http = HTTPURLResponse(
      url: request.url!, statusCode: response.status, httpVersion: "HTTP/1.1",
      headerFields: response.headers)!
    return (response.body, http)
  }

  private func answer(_ route: String) -> StubTransport.Response {
    let parts = route.split(separator: " ", maxSplits: 1).map(String.init)
    let (method, path) = (parts[0], parts[1])
    let segments = path.split(separator: "/").map(String.init)
    switch (method, segments.first ?? "") {
    case ("GET", "user") where segments.count == 1:
      let account = state.withLock { $0.account }
      return .json(
        fixtures["user"]!.replacingOccurrences(
          of: Self.accountA.uuidString.lowercased(), with: account.uuidString.lowercased()))
    case ("GET", "people"): return .json(fixtures["people-page"]!)
    case ("GET", "dives") where segments.count > 1:
      return .json(#"{"volumes":[]}"#)
    case ("GET", "dives"): return .json(fixtures["dives-page"]!)
    case ("GET", "dive") where segments.count == 2:
      return .json(Self.with(fixtures["dive-detail"]!, uuid: segments[1]))
    case ("GET", "dive-draft") where segments.count == 2:
      return .json(Self.with(fixtures["dive-draft"]!, uuid: segments[1]))
    case ("GET", "dive-drafts"):
      let rows = state.withLock { $0.drafts }
      return .json(
        #"{"data":\#(rows),"total_count":0,"has_more":false,"page":1,"items_per_page":100}"#)
    case ("GET", _):
      return .emptyPage
    case ("POST", "auth"):
      switch path {
      case "auth/email/request":
        return .json(#"{"message":"Check your email.","request_id":"\#(UUID().uuidString)"}"#)
      case "auth/email/verify-code":
        return .json(
          #"{"status":"authenticated","email":null,"name":null,"access_token":"fresh","token_type":"bearer"}"#,
          headers: ["Set-Cookie": "refresh_token=fresh; Path=/"])
      case "auth/logout": return .json(#"{"message":"Logged out successfully"}"#)
      default: return .unauthorized
      }
    case ("POST", _):
      let uuid = UUID()
      state.withLock { $0.created.append(uuid) }
      let fixture: String
      switch segments.first! {
      case "dive": fixture = fixtures["dive-detail"]!
      case "dive-draft": fixture = segments.count > 2 ? fixtures["dive-detail"]! : fixtures["dive-draft"]!
      case "dive-site": fixture = fixtures["dive-site"]!
      case "trip": fixture = fixtures["trip"]!
      case "course": fixture = fixtures["course"]!
      case "contact": fixture = fixtures["contact"]!
      case "gear-item": fixture = fixtures["gear-item"]!
      case "gear-set": fixture = Self.firstRow(fixtures["gear-sets-page"]!)
      case "person": fixture = Self.firstRow(fixtures["people-page"]!)
      default: return .json(#"{"detail":"Not Found"}"#, status: 404)
      }
      return .json(Self.with(fixture, uuid: uuid.uuidString.lowercased()), status: 201)
    case ("PATCH", _): return .json(#"{"message":"Updated"}"#)
    case ("DELETE", _): return .json(#"{"message":"Deleted"}"#)
    default: return .json(#"{"detail":"Not Found"}"#, status: 404)
    }
  }

  static func with(_ fixture: String, uuid: String) -> String {
    var object = (try? JSONSerialization.jsonObject(with: Data(fixture.utf8))) as? [String: Any] ?? [:]
    object["uuid"] = uuid
    return String(decoding: try! JSONSerialization.data(withJSONObject: object), as: UTF8.self)
  }

  static func firstRow(_ page: String) -> String {
    let object = (try? JSONSerialization.jsonObject(with: Data(page.utf8))) as? [String: Any]
    let first = (object?["data"] as? [Any])?.first ?? [:]
    return String(decoding: try! JSONSerialization.data(withJSONObject: first), as: UTF8.self)
  }
}

extension StubTransport.Response {
  static func status(_ status: Int, _ detail: String = "No.") -> Self {
    .json(#"{"detail":"\#(detail)"}"#, status: status)
  }
}

/// A session over an ``OutboxServer`` in a directory of its own, and the models a test builds
/// over it.
@MainActor
struct OutboxWorld {
  let server: OutboxServer
  let root: URL
  let log = EventLog()
  let session: Session

  init(server: OutboxServer? = nil, root: URL? = nil, token: String? = "refresh") throws {
    self.server = try server ?? OutboxServer()
    self.root =
      root
      ?? FileManager.default.temporaryDirectory.appendingPathComponent(
        "OutboxTests-\(UUID().uuidString)", isDirectory: true)
    session = Session(
      transport: self.server,
      secrets: InMemorySecretStore(token.map { [OutboxServer.origin.description: $0] } ?? [:]),
      activeOrigin: InMemoryActiveOriginStore(OutboxServer.origin),
      background: LoggingBackgroundExecution(log: log), applicationSupport: self.root,
      userAgent: ClientHarness.userAgent, accessToken: "live")
  }

  /// The same phone, relaunched: a new session over the same directory.
  func relaunched() throws -> OutboxWorld {
    for account in [OutboxServer.accountA, OutboxServer.accountB] {
      OutboxHub.forget(session.store.directory(for: OutboxServer.origin, account: account))
    }
    return try OutboxWorld(server: server, root: root)
  }

  /// Every write the server is sent fails as if there were no route.
  func offline() {
    server.override { request, _ in
      guard request.route.hasPrefix("GET ") else { throw URLError(.notConnectedToInternet) }
      return nil
    }
  }

  func online() {
    server.override { _, _ in nil }
  }

  func outbox(quietInterval: Duration = .milliseconds(50)) -> OutboxModel {
    OutboxModel(session: session, quietInterval: quietInterval)
  }

  /// Loads the account, as the launch does, and tells `model`.
  func load(_ model: OutboxModel? = nil) async throws {
    try await session.loadAccount()
    model?.sessionChanged()
    await model?.settled()
  }

  var storesA: OutboxStore {
    OutboxStore(store: session.store, origin: OutboxServer.origin, account: OutboxServer.accountA)
  }

  var storesB: OutboxStore {
    OutboxStore(store: session.store, origin: OutboxServer.origin, account: OutboxServer.accountB)
  }

  var cacheA: AccountCache {
    AccountCache(store: session.store, origin: OutboxServer.origin, account: OutboxServer.accountA)
  }
}

enum Bodies {
  static let start = DiveTimestamp(wireValue: "2026-10-20T10:00:00+03:00")!

  static func dive(_ number: Int = 1, sites: [RecordRef] = [], people: [RecordRef] = [])
    -> DiveCreate
  {
    DiveCreate(
      diveNumber: number, startTime: start, submergedTime: 3000, diveSites: sites,
      people: people.map { PersonReference(person: $0) })
  }

  static func notes(_ text: String) -> DiveUpdate {
    var update = DiveUpdate()
    update.notes = text
    return update
  }

  static func draft(_ notes: String) -> DiveDraftWrite {
    var values = DiveDraftValues()
    values.notes = notes
    return DiveDraftWrite(values: values)
  }
}
