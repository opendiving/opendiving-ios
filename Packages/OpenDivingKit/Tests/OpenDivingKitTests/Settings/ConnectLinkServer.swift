import Foundation
import OpenDivingKit
import Synchronization

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A server holding the account's connect link, over a ``SettingsServer`` that answers
/// everything else. Any route can be made to answer an error instead.
final class ConnectLinkServer: HTTPTransport {
  private struct State {
    var token: String?
    var minted = 0
    var failing: [String: StubTransport.Response] = [:]
  }

  private let account: SettingsServer
  private let state: Mutex<State>
  private let sent = Mutex<[URLRequest]>([])

  /// A link from the start when `linked`.
  init(linked: Bool = false) throws {
    account = try SettingsServer()
    state = Mutex(State(token: linked ? Self.token(0) : nil))
  }

  /// The token the server minted `n`th; the first is the one a linked server starts with.
  static func token(_ n: Int) -> String {
    String(format: "9f86d081884c7d659a2feaa0c55a%04x", n)
  }

  /// Every request sent so far, in order.
  var requests: [URLRequest] { sent.withLock { $0 } }

  /// What was sent to the link's routes.
  var linkRoutes: [String] {
    requests.map(\.route).filter { $0.hasSuffix("user/connect-link") }
  }

  /// The link's token as the server holds it.
  var token: String? { state.withLock { $0.token } }

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

  private static func json(_ value: Any, status: Int = 200) throws -> StubTransport.Response {
    .json(
      String(decoding: try JSONSerialization.data(withJSONObject: value), as: UTF8.self),
      status: status)
  }

  /// Nil for a route this server leaves to the account's.
  private func answer(_ request: URLRequest) throws -> StubTransport.Response? {
    try state.withLock { state in
      let route = request.route
      if let failing = state.failing[route] { return failing }
      func link() -> [String: Any]? {
        state.token.map { ["token": $0, "created_at": "2026-11-01T10:00:00Z"] }
      }
      switch route {
      case "GET user/connect-link":
        return try link().map { try Self.json($0) }
          ?? .json(#"{"detail":"No connect link"}"#, status: 404)
      case "POST user/connect-link":
        state.minted += 1
        state.token = Self.token(state.minted)
        return try Self.json(link()!, status: 201)
      case "DELETE user/connect-link":
        state.token = nil
        return .json(#"{"message":"Connect link removed"}"#)
      default:
        return nil
      }
    }
  }
}
