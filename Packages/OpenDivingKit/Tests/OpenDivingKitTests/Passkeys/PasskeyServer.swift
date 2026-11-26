import Foundation
import OpenDivingKit
import Synchronization

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A server with passkeys, answering the sign-in's two calls, an account's read, a sign-out
/// and a deletion. Any route can be made to answer otherwise, or to wait at a ``Gate``.
final class PasskeyServer: HTTPTransport {
  private let routes: Mutex<[String: StubTransport.Response]>
  private let gates = Mutex<[String: Gate]>([:])
  private let sent = Mutex<[URLRequest]>([])

  init() throws {
    routes = Mutex([
      "POST auth/passkey/options": .json(try KitFixture.text("passkey-sign-in-options")),
      "POST auth/passkey/verify": Self.authenticated(
        try KitFixture.text("auth-outcome-authenticated")),
      "POST auth/email/verify-code": Self.authenticated(
        try KitFixture.text("auth-outcome-authenticated")),
      "GET user": .json(try KitFixture.text("user")),
      "GET people": .json(try KitFixture.text("people-page")),
      "POST auth/logout": .json(#"{"message":"Logged out successfully"}"#),
      "DELETE user": .json(try KitFixture.text("account-deletion")),
      "POST auth/refresh": .refreshed(access: "fresh", refresh: "refresh-1"),
    ])
  }

  static func authenticated(_ body: String) -> StubTransport.Response {
    .json(body, headers: ["Set-Cookie": "refresh_token=fresh-cookie; HttpOnly; Path=/"])
  }

  var requests: [URLRequest] { sent.withLock { $0 } }

  /// How many times `route` was asked.
  func count(_ route: String) -> Int { requests.filter { $0.route == route }.count }

  func answer(_ route: String, with response: StubTransport.Response) {
    routes.withLock { $0[route] = response }
  }

  /// `route` waits at the gate returned, until it is opened.
  func hold(_ route: String) -> Gate {
    let gate = Gate()
    gates.withLock { $0[route] = gate }
    return gate
  }

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    sent.withLock { $0.append(request) }
    let route = request.route
    if let gate = gates.withLock({ $0.removeValue(forKey: route) }) { await gate.pass() }
    let response =
      routes.withLock { $0[route] } ?? .json(#"{"detail":"Not Found"}"#, status: 404)
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
}
