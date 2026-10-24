import Foundation
import OpenDivingKit
import Synchronization

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A server for the inbox's tests: it signs in as account A or B, answers each preview with
/// what the test chose for it, counts the previews and keeps the filenames each was sent.
final class ImportServer: HTTPTransport {
  static let origin = ServerOrigin("https://dive.example.org")!
  static let accountA = UUID(uuidString: "01a0a51f-afe3-7363-a0bc-b0d634c35923")!
  static let accountB = UUID(uuidString: "01a0a51f-afe3-7363-a0bc-b0d634c3592b")!

  typealias Answer = @Sendable (_ index: Int) async throws -> StubTransport.Response

  private struct State {
    var account = ImportServer.accountA
    var previews: [[String]] = []
    var applies: [[ReceivedPart]] = []
    var routes: [String] = []
    var preview: Answer
    var apply: @Sendable () -> StubTransport.Response
  }

  private let state: Mutex<State>
  private let user: String
  private let people: String
  private let numbering =
    #"{"total_dives":3,"lowest":1,"highest":3,"missing_count":0,"duplicate_count":0,"out_of_date_order_count":0,"is_sequential":true}"#

  init() throws {
    user = try KitFixture.text("user")
    people = try KitFixture.text("people-page")
    let preview = try KitFixture.text("import-preview")
    let result = try KitFixture.text("import-result")
    state = Mutex(
      State(preview: { _ in .json(preview) }, apply: { .json(result) }))
  }

  /// Whom `GET /user` answers as.
  func signIn(as account: UUID) { state.withLock { $0.account = account } }

  func answerPreviews(_ answer: @escaping Answer) { state.withLock { $0.preview = answer } }

  func answerApply(_ answer: @escaping @Sendable () -> StubTransport.Response) {
    state.withLock { $0.apply = answer }
  }

  /// The filenames each preview carried, in the order sent.
  var previews: [[String]] { state.withLock { $0.previews } }
  var applies: [[ReceivedPart]] { state.withLock { $0.applies } }
  var routes: [String] { state.withLock { $0.routes } }

  func upload(_ request: URLRequest, fromFile file: URL) async throws -> (Data, HTTPURLResponse) {
    var request = request
    request.httpBody = try Data(contentsOf: file)
    return try await send(request)
  }

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let route = request.route
    state.withLock { $0.routes.append(route) }
    let response: StubTransport.Response
    switch route {
    case "GET user":
      let account = state.withLock { $0.account }
      response = .json(
        user.replacingOccurrences(
          of: Self.accountA.uuidString.lowercased(), with: account.uuidString.lowercased()))
    case "GET people":
      response = .json(people)
    case "GET dives/numbering":
      response = .json(numbering)
    case "POST import/logbook/preview":
      let names = try ReceivedPart.parts(of: request).compactMap(\.filename)
      let (index, answer) = state.withLock { state in
        state.previews.append(names)
        return (state.previews.count - 1, state.preview)
      }
      response = try await answer(index)
    case "POST import/logbook":
      let parts = try ReceivedPart.parts(of: request)
      response = state.withLock { state in
        state.applies.append(parts)
        return state.apply()
      }
    default:
      response = .json(#"{"detail":"Not Found"}"#, status: 404)
    }
    let http = HTTPURLResponse(
      url: request.url!, statusCode: response.status, httpVersion: "HTTP/1.1",
      headerFields: response.headers)!
    return (response.body, http)
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
