import Foundation
import OpenDivingKit
import Synchronization

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A server holding the invitations the account sent, newest first and paged by offset as the
/// API pages them, and its invite link, over a ``SettingsServer`` that answers everything else.
/// Any route can be made to answer an error instead.
final class InvitationsServer: HTTPTransport {
  private struct State {
    var invitations: [[String: Any]]
    var token: String?
    var minted = 0
    var failing: [String: StubTransport.Response] = [:]
  }

  private let account: SettingsServer
  private let state: Mutex<State>
  private let sent = Mutex<[URLRequest]>([])

  /// `count` pending invitations, `invite-0@example.com` the newest, and a link when `linked`.
  init(count: Int = 3, linked: Bool = false) throws {
    account = try SettingsServer()
    let rows = (0..<count).map {
      Self.row(uuid: Self.uuid(count - 1 - $0), email: "invite-\($0)@example.com")
    }
    state = Mutex(State(invitations: rows, token: linked ? Self.token(0) : nil))
  }

  /// The token the server minted `n`th; the first is the one a linked server starts with.
  static func token(_ n: Int) -> String {
    "invite\(n)Tok_Zr2LmWexampleNotARealToken01234"
  }

  /// Ordered by when the server made them, so a later one sorts after an earlier one.
  static func uuid(_ n: Int) -> UUID {
    UUID(uuidString: String(format: "019a4d5e-6f70-7182-9a3b-%012x", n))!
  }

  private static func row(uuid: UUID, email: String) -> [String: Any] {
    [
      "uuid": uuid.uuidString.lowercased(), "email": email, "created_at": "2026-11-01T10:00:00Z",
      "accepted_at": NSNull(), "revoked_at": NSNull(), "from_invite_link": false,
      "member_name": NSNull(),
    ]
  }

  /// Every request sent so far, in order.
  var requests: [URLRequest] { sent.withLock { $0 } }

  /// What was sent to the invitations' and the link's routes.
  var invitationRoutes: [String] {
    requests.map(\.route).filter { $0.contains("invit") }
  }

  /// The link's token as the server holds it.
  var token: String? { state.withLock { $0.token } }

  /// An invitation made elsewhere — on the web, from the operator's queue — at the top.
  func invite(_ email: String) {
    state.withLock { state in
      state.invitations.insert(
        Self.row(uuid: Self.uuid(state.invitations.count), email: email), at: 0)
    }
  }

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

  private static let notFound = StubTransport.Response.json(#"{"detail":"Not found"}"#, status: 404)

  /// Nil for a route this server leaves to the account's.
  private func answer(_ request: URLRequest) throws -> StubTransport.Response? {
    let route = request.route
    let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
    func number(_ name: String) -> Int? {
      query.first { $0.name == name }?.value.flatMap(Int.init)
    }
    return try state.withLock { state in
      if let failing = state.failing[route] { return failing }
      let body = request.httpBody.flatMap {
        try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
      }
      func link() -> [String: Any]? {
        state.token.map { ["token": $0, "created_at": "2026-11-01T10:00:00Z"] }
      }
      switch route {
      case "GET user/invitations":
        let page = number("page") ?? 1
        let size = number("items_per_page") ?? 10
        let start = min((page - 1) * size, state.invitations.count)
        let end = min(start + size, state.invitations.count)
        return try Self.json([
          "data": Array(state.invitations[start..<end]), "total_count": state.invitations.count,
          "has_more": end < state.invitations.count, "page": page, "items_per_page": size,
        ])
      case "POST user/invitations":
        let email = (body?["email"] as? String ?? "").lowercased()
        if state.invitations.contains(where: { $0["email"] as? String == email }) {
          return .json(#"{"detail":"You have already invited that address."}"#, status: 409)
        }
        let row = Self.row(uuid: Self.uuid(state.invitations.count), email: email)
        state.invitations.insert(row, at: 0)
        return try Self.json(row, status: 201)
      case "GET user/invite-link":
        return try link().map { try Self.json($0) } ?? Self.notFound
      case "POST user/invite-link":
        state.minted += 1
        state.token = Self.token(state.minted)
        return try Self.json(link()!, status: 201)
      case "DELETE user/invite-link":
        state.token = nil
        return .json(#"{"message":"Invite link removed"}"#)
      default:
        break
      }
      if route.hasPrefix("DELETE user/invitation/") {
        let uuid = String(route.split(separator: "/").last ?? "")
        guard let at = state.invitations.firstIndex(where: { $0["uuid"] as? String == uuid })
        else { return Self.notFound }
        state.invitations[at]["revoked_at"] = "2026-11-10T12:00:00Z"
        return .json(#"{"message":"Invitation revoked"}"#)
      }
      return nil
    }
  }
}
