import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

extension APIClient {
  /// Sends a queued write with the bytes the outbox holds for it and hands back the answer
  /// unread, whatever its status, so the outbox sorts it itself. A keyed create's bytes are
  /// the ones its first try sent, which the key's hold digests.
  func sendQueued(method: String, path: String, body: Data?, idempotencyKey: UUID?) async throws
    -> (Data, HTTPURLResponse)
  {
    var headers: [String: String] = [:]
    if let idempotencyKey { headers["Idempotency-Key"] = Self.wire(idempotencyKey) }
    return try await authorized(
      Call(method: method, path: path, body: body, headers: headers))
  }

  /// The detail sentence of an error answer, as ``APIError/http(status:message:)`` carries it.
  static func detail(of data: Data) -> String? {
    (try? APICoding.decoder().decode(ErrorDetail.self, from: data))?.message
  }
}
