import Foundation
import OpenDivingKit
import Synchronization

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A server that never answers: every request is held until the task that sent it is
/// cancelled, as `URLSession` honours, or ``release()`` fails them all as timed out.
final class SilentTransport: HTTPTransport {
  private struct Held {
    var waiting: [UUID: CheckedContinuation<Void, any Error>] = [:]
    var cancelled: Set<UUID> = []
    var released = false
  }

  private let held = Mutex(Held())
  private let sent = Mutex<[URLRequest]>([])

  var requests: [URLRequest] { sent.withLock { $0 } }

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    sent.withLock { $0.append(request) }
    let id = UUID()
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<Void, any Error>) in
        let failure: URLError? = held.withLock { held in
          if held.released { return URLError(.timedOut) }
          if held.cancelled.contains(id) { return URLError(.cancelled) }
          held.waiting[id] = continuation
          return nil
        }
        if let failure { continuation.resume(throwing: failure) }
      }
    } onCancel: {
      let continuation: CheckedContinuation<Void, any Error>? = held.withLock { held in
        if let continuation = held.waiting.removeValue(forKey: id) { return continuation }
        held.cancelled.insert(id)
        return nil
      }
      continuation?.resume(throwing: URLError(.cancelled))
    }
    // Only ever resumed by throwing.
    throw URLError(.timedOut)
  }

  func upload(_ request: URLRequest, fromFile file: URL) async throws -> (Data, HTTPURLResponse) {
    try await send(request)
  }

  /// Fails every request held, and every one sent after, as timed out.
  func release() {
    let waiting = held.withLock { held in
      held.released = true
      defer { held.waiting = [:] }
      return Array(held.waiting.values)
    }
    for continuation in waiting { continuation.resume(throwing: URLError(.timedOut)) }
  }
}
