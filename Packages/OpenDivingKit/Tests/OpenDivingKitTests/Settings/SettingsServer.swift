import Foundation
import OpenDivingKit
import Synchronization

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A server holding one account, which `PATCH /user` changes, `GET /user` answers and
/// `DELETE /user` schedules for deletion, its check-in details, which
/// `PATCH /user/checkin-details` changes, a confirmation link `POST /user/email-change/request`
/// mails, the diver's tags, which `PATCH /tag/{uuid}` renames and `DELETE /tag/{uuid}` removes,
/// what the account stores and its four exports, and the account's two pictures, which
/// `PUT`, `PATCH` and `DELETE /user/{avatar,portrait}` and `POST /user/portrait/from-avatar`
/// change. Any route can be made to answer an error instead, and one request can be held at a
/// ``Gate``.
final class SettingsServer: HTTPTransport {
  private struct State {
    var user: [String: Any]
    var checkin: [String: Any]
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
    let checkin =
      try JSONSerialization.jsonObject(with: KitFixture.data("checkin-details"))
      as! [String: Any]
    state = Mutex(State(user: user, checkin: checkin, tags: page["data"] as! [[String: Any]]))
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

  /// The check-in details as the server holds them.
  func checkinDetails() throws -> CheckinDetailsRead {
    let data = try state.withLock { try JSONSerialization.data(withJSONObject: $0.checkin) }
    return try APICoding.decoder().decode(CheckinDetailsRead.self, from: data)
  }

  /// Changes a check-in detail behind the phone's back, as the web would.
  func setCheckin(_ key: String, _ value: some Sendable) {
    state.withLock { $0.checkin[key] = value }
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
      case "GET user/checkin-details":
        return .json(
          String(
            decoding: try JSONSerialization.data(withJSONObject: state.checkin), as: UTF8.self))
      case "PATCH user/checkin-details":
        for (key, value) in body ?? [:] { state.checkin[key] = value }
        return .json(
          String(
            decoding: try JSONSerialization.data(withJSONObject: state.checkin), as: UTF8.self))
      case "POST auth/logout":
        return .json(#"{"message":"Logged out successfully"}"#)
      case "POST user/email-change/request":
        return .json(#"{"message":"Check your new email address to confirm the change."}"#)
      case "DELETE user":
        return .json(try KitFixture.text("account-deletion"))
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
      if let picture = Self.picture(route, request.httpBody, user: &state.user) {
        return picture
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

extension SettingsServer {
  /// What the picture routes answer, over the account's picture keys; nil for any other route.
  /// A write names its new version after the route, so a test can tell which one landed.
  fileprivate static func picture(_ route: String, _ raw: Data?, user: inout [String: Any])
    -> StubTransport.Response?
  {
    let body = raw.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    let parts = route.split(separator: " ")
    guard parts.count == 2 else { return nil }
    let (method, path) = (parts[0], parts[1])
    let kind: String
    switch path {
    case "user/avatar", "user/avatar/original": kind = "avatar"
    case "user/portrait", "user/portrait/original", "user/portrait/from-avatar": kind = "portrait"
    default: return nil
    }
    let sha = user["\(kind)_sha256"] as? String
    let original = user["\(kind)_original_sha256"] as? String
    func written(_ version: String, crop: Any?) -> StubTransport.Response {
      user["\(kind)_sha256"] = version
      if let crop { user["\(kind)_crop"] = crop }
      return .json(#"{"sha256":"\#(version)"}"#)
    }
    switch (method, path) {
    case ("GET", "user/\(kind)"):
      guard let sha else { return .json(#"{"detail":"No \#(kind) set"}"#, status: 404) }
      return StubTransport.Response(
        headers: ["Content-Type": "image/webp", "ETag": "\"\(sha)\""], body: Data(sha.utf8))
    case ("GET", "user/\(kind)/original"):
      guard let original else { return .json(#"{"detail":"No \#(kind) set"}"#, status: 404) }
      return StubTransport.Response(
        headers: ["Content-Type": "image/jpeg"], body: Data(original.utf8))
    case ("PUT", "user/\(kind)"):
      user["\(kind)_original_sha256"] = "uploaded-\(kind)-original"
      return written("uploaded-\(kind)", crop: raw.flatMap(Self.formCrop))
    case ("PATCH", "user/\(kind)"):
      guard original != nil else {
        return .json(#"{"detail":"The \#(kind) has no original to adjust"}"#, status: 404)
      }
      return written("adjusted-\(kind)", crop: body?["crop"])
    case ("POST", "user/portrait/from-avatar"):
      guard let avatarOriginal = user["avatar_original_sha256"] as? String else {
        return .json(#"{"detail":"The avatar has no original to copy"}"#, status: 404)
      }
      user["portrait_original_sha256"] = avatarOriginal
      return written("copied-portrait", crop: body?["crop"])
    case ("DELETE", "user/\(kind)"):
      guard sha != nil else { return .json(#"{"detail":"No \#(kind) set"}"#, status: 404) }
      for key in ["sha256", "original_sha256", "crop"] { user["\(kind)_\(key)"] = NSNull() }
      return .json(#"{"message":"Removed"}"#)
    default:
      return nil
    }
  }

  /// The `crop` field of a multipart body, as the JSON it carries.
  static func formCrop(_ body: Data) -> Any? {
    let text = String(decoding: body, as: UTF8.self)
    guard let field = text.range(of: "name=\"crop\"\r\n\r\n") else { return nil }
    let rest = text[field.upperBound...]
    // A line break is one character, so the field ends at the first scalar of one.
    let value = String(String.UnicodeScalarView(rest.unicodeScalars.prefix { $0 != "\r" }))
    return try? JSONSerialization.jsonObject(with: Data(value.utf8))
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
