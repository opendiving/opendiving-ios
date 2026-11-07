import Foundation
import OpenDivingKit
import Synchronization
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A server for the inbox's tests: it signs in as account A or B and holds imports as the API
/// does, one pending at a time, and each test can answer an upload or an apply its own way or act
/// as another device. It counts the uploads and keeps the filenames each was sent.
final class ImportServer: HTTPTransport {
  static let origin = ServerOrigin("https://dive.example.org")!
  static let accountA = UUID(uuidString: "01a0a51f-afe3-7363-a0bc-b0d634c35923")!
  static let accountB = UUID(uuidString: "01a0a51f-afe3-7363-a0bc-b0d634c3592b")!

  typealias Answer = @Sendable (_ index: Int) async throws -> StubTransport.Response?

  private struct Held {
    var files: [String]
    var applied = false
  }

  private struct State {
    var account = ImportServer.accountA
    var uploads: [[String]] = []
    var applies: [Data] = []
    var discards: [String] = []
    var routes: [String] = []
    var held: [UUID: Held] = [:]
    /// The parts each upload refuses as rows, past the files nothing reads.
    var refused: Set<Int> = []
    /// Answers an upload in place of the server when it does not answer nil.
    var upload: Answer = { _ in nil }
    var apply: @Sendable () -> StubTransport.Response? = { nil }
    var discard: @Sendable () -> StubTransport.Response? = { nil }
    var pendingRead: @Sendable () async throws -> Void = {}
  }

  private let state = Mutex(State())
  private let user: String
  private let people: String
  private let dives: String
  private let review: String
  private let numbering =
    #"{"total_dives":3,"lowest":1,"highest":3,"missing_count":0,"duplicate_count":0,"out_of_date_order_count":0,"is_sequential":true}"#

  init() throws {
    user = try KitFixture.text("user")
    people = try KitFixture.text("people-page")
    dives = try KitFixture.text("dives-page")
    review = try KitFixture.text("import-pending")
  }

  /// Whom `GET /user` answers as.
  func signIn(as account: UUID) { state.withLock { $0.account = account } }

  func answerUploads(_ answer: @escaping Answer) { state.withLock { $0.upload = answer } }

  func answerApply(_ answer: @escaping @Sendable () -> StubTransport.Response?) {
    state.withLock { $0.apply = answer }
  }

  func answerDiscard(_ answer: @escaping @Sendable () -> StubTransport.Response?) {
    state.withLock { $0.discard = answer }
  }

  /// Runs before each pending read is answered, which may throw in its place.
  func beforePendingRead(_ run: @escaping @Sendable () async throws -> Void) {
    state.withLock { $0.pendingRead = run }
  }

  func refuse(parts: Set<Int>) { state.withLock { $0.refused = parts } }

  /// Another device's upload.
  @discardableResult func holdElsewhere(_ files: [String] = ["elsewhere.fit"]) -> UUID {
    let uuid = UUID()
    state.withLock { $0.held[uuid] = Held(files: files) }
    return uuid
  }

  /// Another device's apply of the pending import.
  func applyElsewhere() {
    state.withLock { state in
      guard let uuid = Self.pending(state) else { return }
      state.held[uuid]?.applied = true
    }
  }

  /// Another device's discard, or the pending import's expiry.
  func discardElsewhere() {
    state.withLock { state in
      guard let uuid = Self.pending(state) else { return }
      state.held[uuid] = nil
    }
  }

  /// The filenames each upload carried, in the order sent.
  var uploads: [[String]] { state.withLock { $0.uploads } }
  /// The body of each apply.
  var applies: [Data] { state.withLock { $0.applies } }
  /// The query of each `DELETE /import/{uuid}`.
  var discards: [String] { state.withLock { $0.discards } }
  var routes: [String] { state.withLock { $0.routes } }
  var pendingUUID: UUID? { state.withLock { Self.pending($0) } }

  func upload(_ request: URLRequest, fromFile file: URL) async throws -> (Data, HTTPURLResponse) {
    var request = request
    request.httpBody = try Data(contentsOf: file)
    return try await send(request)
  }

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let route = request.route
    state.withLock { $0.routes.append(route) }
    let response = try await answer(route, request)
    let http = HTTPURLResponse(
      url: request.url!, statusCode: response.status, httpVersion: "HTTP/1.1",
      headerFields: response.headers)!
    return (response.body, http)
  }

  private func answer(_ route: String, _ request: URLRequest) async throws
    -> StubTransport.Response
  {
    let notFound = StubTransport.Response.json(#"{"detail":"Import not found"}"#, status: 404)
    switch route {
    case "GET user":
      let account = state.withLock { $0.account }
      return .json(
        user.replacingOccurrences(
          of: Self.accountA.uuidString.lowercased(), with: account.uuidString.lowercased()))
    case "GET people":
      return .json(people)
    case "GET dives":
      return .json(dives)
    case "GET dives/numbering":
      return .json(numbering)
    case "POST imports":
      return try await upload(try ReceivedPart.parts(of: request).compactMap(\.filename))
    case "GET imports/pending":
      try await state.withLock { $0.pendingRead }()
      return try state.withLock { state in
        guard let uuid = Self.pending(state) else { return notFound }
        return .json(try body(uuid, state))
      }
    default:
      break
    }
    guard let uuid = request.url.flatMap({ Self.importUUID($0) }) else {
      return .json(#"{"detail":"Not Found"}"#, status: 404)
    }
    switch request.httpMethod {
    case "GET":
      return try state.withLock { state in
        state.held[uuid] == nil ? notFound : .json(try body(uuid, state))
      }
    case "POST":
      return try state.withLock { state in
        state.applies.append(request.httpBody ?? Data())
        if let answer = state.apply() { return answer }
        guard let held = state.held[uuid] else { return notFound }
        guard !held.applied else {
          return .json(#"{"detail":"This import has already been applied."}"#, status: 409)
        }
        state.held[uuid]?.applied = true
        return .json(try body(uuid, state))
      }
    default:
      return state.withLock { state in
        state.discards.append(request.url?.query ?? "")
        if let answer = state.discard() { return answer }
        guard let held = state.held[uuid] else { return notFound }
        guard !held.applied else {
          return .json(#"{"detail":"This import is applied, not pending."}"#, status: 409)
        }
        state.held[uuid] = nil
        return StubTransport.Response(status: 204, body: Data())
      }
    }
  }

  private func upload(_ names: [String]) async throws -> StubTransport.Response {
    let (index, answer) = state.withLock { state in
      state.uploads.append(names)
      return (state.uploads.count - 1, state.upload)
    }
    if let answered = try await answer(index) { return answered }
    return try state.withLock { state in
      if let pending = Self.pending(state) {
        return .json(
          #"{"detail":"Import \#(pending) is waiting to be finished. Apply it or discard it before uploading another."}"#,
          status: 409)
      }
      let uuid = UUID()
      state.held[uuid] = Held(files: names)
      return .json(try body(uuid, state), status: 201)
    }
  }

  private static func pending(_ state: State) -> UUID? {
    state.held.first { !$0.value.applied }?.key
  }

  private static func importUUID(_ url: URL) -> UUID? {
    let parts = url.pathComponents
    guard let index = parts.firstIndex(of: "import"), parts.indices.contains(index + 1) else {
      return nil
    }
    return UUID(uuidString: parts[index + 1])
  }

  /// `import-pending.json` as the import `uuid`, its members the files it holds. A `.txt` is
  /// refused, as is a part the test named.
  private func body(_ uuid: UUID, _ state: State) throws -> String {
    guard let held = state.held[uuid] else { throw URLError(.badServerResponse) }
    var json = try #require(
      try JSONSerialization.jsonObject(with: Data(review.utf8)) as? [String: Any])
    json["uuid"] = uuid.uuidString.lowercased()
    json["status"] = held.applied ? "applied" : "pending"
    json["applied_at"] = held.applied ? "2026-11-07T12:00:00+00:00" : NSNull()
    json["members"] = held.files.enumerated().map { part, name in
      let refused = name.hasSuffix(".txt") || state.refused.contains(part)
      return [
        "part": part, "container": NSNull(), "name": name, "byte_size": 1,
        "sha256": String(repeating: "0", count: 64), "format": refused ? NSNull() : "fit",
        "opened": NSNull(), "kept": !refused, "not_kept": NSNull(),
        "refusal": refused ? "This file is not one OpenDiving reads." : NSNull(),
      ] as [String: Any]
    }
    return String(decoding: try JSONSerialization.data(withJSONObject: json), as: UTF8.self)
  }
}

/// A place to make files to hand to the inbox.
struct SharedFiles {
  let folder = FileManager.default.temporaryDirectory
    .appendingPathComponent("SharedFiles-\(UUID().uuidString)", isDirectory: true)

  /// A file named `name` holding `bytes`, in a folder of its own so two can share a name.
  func make(_ name: String, bytes: String = "dive") throws -> URL {
    let dir = folder.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent(name)
    try Data(bytes.utf8).write(to: url)
    return url
  }
}
