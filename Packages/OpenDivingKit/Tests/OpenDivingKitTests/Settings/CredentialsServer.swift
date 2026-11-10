import Foundation
import OpenDivingKit
import Synchronization

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A server holding the account's passkeys, signed-in devices and API keys, over a
/// ``SettingsServer`` that answers everything else. Any route can be made to answer an error
/// instead.
final class CredentialsServer: HTTPTransport {
  private struct State {
    var passkeys: [[String: Any]]
    var sessions: [[String: Any]]
    var keys: [[String: Any]]
    var failing: [String: StubTransport.Response] = [:]
  }

  /// The secret every created key carries.
  static let secret = "odk_Hn4tW7cEexampleSecretNotARealKey0123456789a"

  private let account: SettingsServer
  private let state: Mutex<State>
  private let sent = Mutex<[URLRequest]>([])

  init() throws {
    account = try SettingsServer()
    func rows(_ name: String) throws -> [[String: Any]] {
      try JSONSerialization.jsonObject(with: KitFixture.data(name)) as! [[String: Any]]
    }
    state = Mutex(
      State(
        passkeys: try rows("passkeys"), sessions: try rows("user-sessions"),
        keys: try rows("api-keys")))
  }

  /// Every request sent so far, in order.
  var requests: [URLRequest] { sent.withLock { $0 } }

  /// What was sent that is not the session's own refresh or the account's read.
  var credentialRoutes: [String] {
    requests.map(\.route).filter { $0.contains("passkey") || $0.contains("session") || $0.contains("api-key") }
  }

  var keyCount: Int { state.withLock { $0.keys.count } }

  /// `route` answers `response` until ``succeed(_:)``.
  func fail(_ route: String, with response: StubTransport.Response) {
    state.withLock { $0.failing[route] = response }
  }

  func succeed(_ route: String) {
    state.withLock { $0.failing[route] = nil }
  }

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    sent.withLock { $0.append(request) }
    guard let response = try answer(request) else { return try await account.send(request) }
    let http = HTTPURLResponse(
      url: request.url!, statusCode: response.status, httpVersion: "HTTP/1.1",
      headerFields: response.headers)!
    return (response.body, http)
  }

  func upload(_ request: URLRequest, fromFile file: URL) async throws -> (Data, HTTPURLResponse) {
    var request = request
    request.httpBody = try Data(contentsOf: file)
    return try await send(request)
  }

  private static func json(_ value: Any) throws -> StubTransport.Response {
    .json(String(decoding: try JSONSerialization.data(withJSONObject: value), as: UTF8.self))
  }

  private static let notFound = StubTransport.Response.json(#"{"detail":"Not found"}"#, status: 404)

  /// Nil for a route this server leaves to the account's.
  private func answer(_ request: URLRequest) throws -> StubTransport.Response? {
    let route = request.route
    return try state.withLock { state in
      if let failing = state.failing[route] { return failing }
      let body = request.httpBody.flatMap {
        try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
      }
      let uuid = String(route.split(separator: "/").last ?? "")
      func index(_ rows: [[String: Any]]) -> Int? {
        rows.firstIndex { ($0["uuid"] as? String) == uuid }
      }
      switch route {
      case "GET user/passkeys": return try Self.json(state.passkeys)
      case "GET user/sessions": return try Self.json(state.sessions)
      case "GET user/api-keys": return try Self.json(state.keys)
      case "DELETE user/sessions":
        let others = state.sessions.filter { $0["current"] as? Bool != true }
        state.sessions.removeAll { $0["current"] as? Bool != true }
        return try Self.json(["message": "Signed out", "revoked": others.count])
      case "POST user/api-keys":
        var row: [String: Any] = [
          "uuid": "019a3c4d-5e6f-7081-9a2b-3c4d5e6f7a82", "name": body?["name"] ?? "",
          "prefix": String(Self.secret.prefix(12)), "scope": body?["scope"] ?? "",
          "created_at": "2026-11-10T12:00:00Z", "last_used_at": NSNull(),
          "expires_at": "2026-12-10T12:00:00Z",
        ]
        state.keys.append(row)
        row["secret"] = Self.secret
        var response = try Self.json(row)
        response.status = 201
        return response
      default:
        break
      }
      if route.hasPrefix("PATCH user/passkey/") {
        guard let at = index(state.passkeys) else { return Self.notFound }
        state.passkeys[at]["name"] = body?["name"]
        return .json(#"{"message":"Passkey updated"}"#)
      }
      if route.hasPrefix("DELETE user/passkey/") {
        guard let at = index(state.passkeys) else { return Self.notFound }
        state.passkeys.remove(at: at)
        return .json(#"{"message":"Passkey removed"}"#)
      }
      if route.hasPrefix("DELETE user/session/") {
        guard let at = index(state.sessions) else { return Self.notFound }
        if state.sessions[at]["current"] as? Bool == true {
          return .json(#"{"detail":"Sign out to end this session"}"#, status: 409)
        }
        state.sessions.remove(at: at)
        return .json(#"{"message":"Session revoked"}"#)
      }
      if route.hasPrefix("DELETE user/api-key/") {
        guard let at = index(state.keys) else { return Self.notFound }
        state.keys.remove(at: at)
        return .json(#"{"message":"API key revoked"}"#)
      }
      return nil
    }
  }
}
