import Foundation
import OpenDivingKit
import Synchronization

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A server holding one account, which `PATCH /user` changes and `GET /user` answers, the
/// diver's tags, which `PATCH /tag/{uuid}` renames and `DELETE /tag/{uuid}` removes, what the
/// account stores and its four exports. Any route can be made to answer an error instead, and
/// one request can be held at a ``Gate``.
final class SettingsServer: HTTPTransport {
  private struct State {
    var user: [String: Any]
    var tags: [[String: Any]]
    var failing: [String: StubTransport.Response] = [:]
    var holding: (route: String, gate: Gate)?
  }

  private let state: Mutex<State>
  private let sent = Mutex<[URLRequest]>([])

  init() throws {
    let user = try JSONSerialization.jsonObject(with: KitFixture.data("user")) as! [String: Any]
    let page =
      try JSONSerialization.jsonObject(with: KitFixture.data("tags-page")) as! [String: Any]
    state = Mutex(State(user: user, tags: page["data"] as! [[String: Any]]))
  }

  /// Every request sent so far, in order.
  var requests: [URLRequest] { sent.withLock { $0 } }

  /// The account as the server holds it.
  func user() throws -> UserRead {
    let data = try state.withLock { try JSONSerialization.data(withJSONObject: $0.user) }
    return try APICoding.decoder().decode(UserRead.self, from: data)
  }

  /// Changes the account behind the phone's back, as the web would.
  func set(_ key: String, _ value: some Sendable) {
    state.withLock { $0.user[key] = value }
  }

  /// `route` answers `response` until ``succeed(_:)``.
  func fail(_ route: String, with response: StubTransport.Response) {
    state.withLock { $0.failing[route] = response }
  }

  func succeed(_ route: String) {
    state.withLock { $0.failing[route] = nil }
  }

  /// The next request to `route` waits at `gate`.
  func hold(_ route: String, at gate: Gate) {
    state.withLock { $0.holding = (route, gate) }
  }

  /// What `GET /export/{format}` names its file.
  static func exportName(_ format: String) -> String {
    "opendiving-diver-20261110.\(format == "archive" ? "zip" : format)"
  }

  /// What `GET /export/{format}` answers.
  static func exportBody(_ format: String) -> String {
    "the \(format) export"
  }

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    sent.withLock { $0.append(request) }
    let route = request.route
    let gate: Gate? = state.withLock { state in
      guard let holding = state.holding, holding.route == route else { return nil }
      state.holding = nil
      return holding.gate
    }
    if let gate { await gate.pass() }
    let response = try answer(request, route)
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

  private func answer(_ request: URLRequest, _ route: String) throws -> StubTransport.Response {
    try state.withLock { state in
      if let failing = state.failing[route] { return failing }
      let body = request.httpBody.flatMap {
        try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
      }
      switch route {
      case "POST auth/refresh":
        return .refreshed(access: "fresh", refresh: "refresh-1")
      case "GET user":
        return .json(
          String(decoding: try JSONSerialization.data(withJSONObject: state.user), as: UTF8.self))
      case "PATCH user":
        for (key, value) in body ?? [:] { state.user[key] = value }
        return .json(#"{"message":"User updated"}"#)
      case "POST auth/logout":
        return .json(#"{"message":"Logged out successfully"}"#)
      case "GET user/storage":
        return .json(try KitFixture.text("storage"))
      case "GET people":
        return .json(try KitFixture.text("people-page"))
      case "GET tags":
        let page: [String: Any] = [
          "data": state.tags, "total_count": state.tags.count, "has_more": false, "page": 1,
          "items_per_page": 50,
        ]
        return .json(
          String(decoding: try JSONSerialization.data(withJSONObject: page), as: UTF8.self))
      default:
        break
      }
      if route.hasPrefix("GET export/") {
        let format = String(route.dropFirst("GET export/".count))
        return StubTransport.Response(
          headers: [
            "Content-Type": "application/octet-stream",
            "Content-Disposition": #"attachment; filename="\#(Self.exportName(format))""#,
          ],
          body: Data(Self.exportBody(format).utf8))
      }
      if route.hasPrefix("PATCH tag/") || route.hasPrefix("DELETE tag/") {
        let uuid = String(route.split(separator: "/").last ?? "")
        guard let index = state.tags.firstIndex(where: { ($0["uuid"] as? String) == uuid }) else {
          return .json(#"{"detail":"Tag not found"}"#, status: 404)
        }
        if route.hasPrefix("DELETE") {
          state.tags.remove(at: index)
          return .json(#"{"message":"Tag deleted"}"#)
        }
        state.tags[index]["name"] = body?["name"]
        return .json(#"{"message":"Tag updated"}"#)
      }
      return .json(#"{"detail":"Not Found"}"#, status: 404)
    }
  }
}

/// A route that comes and goes, and an app that returns to the foreground, on cue.
final class SettingsConnectivity: Connectivity {
  private let state:
    Mutex<
      (available: Bool, appearances: Int, streams: [AsyncStream<ConnectivityMoment>.Continuation])
    >

  init(available: Bool = true) {
    state = Mutex((available, 0, []))
  }

  var isRouteAvailable: Bool {
    get { state.withLock { $0.available } }
    set { state.withLock { $0.available = newValue } }
  }

  var routeAppearances: Int { state.withLock { $0.appearances } }

  /// Whether anything is following the moments yet.
  var isFollowed: Bool { state.withLock { !$0.streams.isEmpty } }

  func moments() -> AsyncStream<ConnectivityMoment> {
    let (stream, continuation) = AsyncStream<ConnectivityMoment>.makeStream()
    state.withLock { $0.streams.append(continuation) }
    return stream
  }

  func appear() {
    let streams = state.withLock { state in
      state.available = true
      state.appearances += 1
      return state.streams
    }
    for stream in streams { stream.yield(.routeAppeared) }
  }

  func becomeActive() {
    for stream in state.withLock({ $0.streams }) { stream.yield(.becameActive) }
  }
}
