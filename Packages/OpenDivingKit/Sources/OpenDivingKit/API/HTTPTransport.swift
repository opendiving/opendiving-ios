import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// What sends a request and hands back the answer. `URLSessionTransport` on the device;
/// ``StubTransport`` in tests and previews.
public protocol HTTPTransport: Sendable {
  /// Throws a `URLError` when no answer arrived.
  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)

  /// Sends `request` with the contents of `file` as its body, which the system streams from
  /// disk rather than holding it in memory. Throws a `URLError` when no answer arrived.
  func upload(_ request: URLRequest, fromFile file: URL) async throws -> (Data, HTTPURLResponse)
}
