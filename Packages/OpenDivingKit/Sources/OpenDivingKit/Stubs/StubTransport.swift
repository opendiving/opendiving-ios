import Foundation
import Synchronization

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A transport that answers from a handler instead of a network, and keeps every request it
/// was sent: the Kit's tests use it, and the app bundle's tests build a ``Session`` over one
/// through ``Session/stub(origin:transport:)``.
public final class StubTransport: HTTPTransport {
  /// One canned answer.
  public struct Response: Sendable {
    public var status: Int
    public var headers: [String: String]
    public var body: Data

    public init(status: Int = 200, headers: [String: String] = [:], body: Data = Data()) {
      self.status = status
      self.headers = headers
      self.body = body
    }

    /// A JSON body, given as its text.
    public static func json(_ text: String, status: Int = 200, headers: [String: String] = [:])
      -> Response
    {
      var headers = headers
      headers["Content-Type"] = "application/json"
      return Response(status: status, headers: headers, body: Data(text.utf8))
    }
  }

  public typealias Handler = @Sendable (URLRequest) throws -> Response

  private let handler: Handler
  private let sent = Mutex<[URLRequest]>([])

  /// `handler` answers each request; throwing a `URLError` stands for no answer at all.
  public init(_ handler: @escaping Handler) {
    self.handler = handler
  }

  /// Answers from `routes`, keyed by method and the path under `/api/v1` — `"GET dives"`,
  /// `"POST auth/refresh"` — whatever the query; anything else is a 404.
  public convenience init(routes: [String: Response]) {
    self.init { request in
      routes[StubTransport.routeKey(request)]
        ?? .json(#"{"detail":"Not Found"}"#, status: 404)
    }
  }

  /// Every request sent so far, in order. An upload's is there with the file's contents as
  /// its `httpBody`, read before the handler answers.
  public var requests: [URLRequest] {
    sent.withLock { $0 }
  }

  /// `"GET dives"` for `GET {origin}/api/v1/dives?page=1`.
  public static func routeKey(_ request: URLRequest) -> String {
    let path = request.url?.path ?? ""
    let prefix = "/api/v1/"
    let route = path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : path
    return "\(request.httpMethod ?? "GET") \(route)"
  }

  public func upload(_ request: URLRequest, fromFile file: URL) async throws
    -> (Data, HTTPURLResponse)
  {
    var request = request
    request.httpBody = try Data(contentsOf: file)
    return try await send(request)
  }

  public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    sent.withLock { $0.append(request) }
    let response = try handler(request)
    guard
      let url = request.url,
      let http = HTTPURLResponse(
        url: url, statusCode: response.status, httpVersion: "HTTP/1.1",
        headerFields: response.headers)
    else { throw URLError(.badServerResponse) }
    return (response.body, http)
  }
}
