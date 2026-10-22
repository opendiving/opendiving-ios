import Foundation
import OpenDivingKit
import Synchronization

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// An ordered record of what the transport, the secret store and the background-execution
/// fake did, so a test can read the order they did it in.
final class EventLog: Sendable {
  private let events = Mutex<[String]>([])

  func append(_ event: String) {
    events.withLock { $0.append(event) }
  }

  var all: [String] { events.withLock { $0 } }
}

/// A ``SecretStore`` over memory that logs its writes and removals.
final class LoggingSecretStore: SecretStore {
  let log: EventLog
  private let inner: InMemorySecretStore

  init(log: EventLog, secrets: [String: String] = [:]) {
    self.log = log
    inner = InMemorySecretStore(secrets)
  }

  func secret(for account: String) throws -> String? {
    try inner.secret(for: account)
  }

  func setSecret(_ value: String, for account: String) throws {
    log.append("write \(value)")
    try inner.setSecret(value, for: account)
  }

  func removeSecret(for account: String) throws {
    log.append("remove")
    try inner.removeSecret(for: account)
  }
}

/// A ``BackgroundExecution`` that logs its assertions.
final class LoggingBackgroundExecution: BackgroundExecution {
  let log: EventLog
  private let next = Mutex(0)

  init(log: EventLog) {
    self.log = log
  }

  func begin(name: String) async -> BackgroundExecutionToken {
    let token = next.withLock { value in
      value += 1
      return value
    }
    log.append("begin")
    return BackgroundExecutionToken(rawValue: token)
  }

  func end(_ token: BackgroundExecutionToken) async {
    log.append("end")
  }
}

/// One client over a stub transport, with every collaborator logging into one ``EventLog``.
struct ClientHarness {
  static let origin = ServerOrigin("https://dive.example.org")!
  static let userAgent = UserAgent(appVersion: "1.2.3", systemVersion: "18.6", model: "iPhone")

  let log = EventLog()
  let transport: StubTransport
  let secrets: LoggingSecretStore
  let background: LoggingBackgroundExecution
  let client: APIClient

  /// `handler` answers each request after the transport has logged `send <route>`.
  init(
    refreshToken: String? = "refresh-0",
    accessToken: String? = nil,
    handler: @escaping StubTransport.Handler
  ) {
    let log = log
    transport = StubTransport { request in
      log.append("send \(StubTransport.routeKey(request))")
      return try handler(request)
    }
    secrets = LoggingSecretStore(
      log: log, secrets: refreshToken.map { [Self.origin.description: $0] } ?? [:])
    background = LoggingBackgroundExecution(log: log)
    client = APIClient(
      origin: Self.origin, transport: transport, secrets: secrets, background: background,
      userAgent: Self.userAgent, accessToken: accessToken
    ) {
      log.append("session ended")
    }
  }

  var sessionEnded: Bool { log.all.contains("session ended") }

  var storedRefreshToken: String? {
    try? secrets.secret(for: Self.origin.description)
  }
}

extension URLRequest {
  var bearer: String? {
    value(forHTTPHeaderField: "Authorization").map { String($0.dropFirst("Bearer ".count)) }
  }

  var cookie: String? { value(forHTTPHeaderField: "Cookie") }

  var route: String { StubTransport.routeKey(self) }
}

extension StubTransport.Response {
  /// `POST /auth/refresh`'s success: a new access token and a rotated cookie.
  static func refreshed(access: String, refresh: String) -> Self {
    .json(
      #"{"access_token":"\#(access)","token_type":"bearer"}"#,
      headers: [
        "Set-Cookie": "refresh_token=\(refresh); HttpOnly; Max-Age=604800; Path=/; SameSite=lax"
      ])
  }

  static let unauthorized = Self.json(#"{"detail":"Invalid token."}"#, status: 401)
  static let emptyPage = Self.json(
    #"{"data":[],"total_count":0,"has_more":false,"page":1,"items_per_page":50}"#)
}
