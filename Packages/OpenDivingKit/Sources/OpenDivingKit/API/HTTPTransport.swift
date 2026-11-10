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

  /// Sends `request` and writes the answer's body to a new file as it arrives, rather than
  /// holding it in memory. The file is the caller's to move or remove. Throws a `URLError` when
  /// no answer arrived.
  func download(_ request: URLRequest) async throws -> (URL, HTTPURLResponse)
}

extension HTTPTransport {
  /// The body as ``send(_:)`` answers it, written out whole: for a transport that holds its
  /// answers in memory anyway, as the stubs do.
  public func download(_ request: URLRequest) async throws -> (URL, HTTPURLResponse) {
    let (data, response) = try await send(request)
    let file = FileManager.default.temporaryDirectory
      .appendingPathComponent("download-\(UUID().uuidString)")
    try data.write(to: file)
    return (file, response)
  }
}
