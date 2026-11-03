import Foundation
import Synchronization

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// One client's requests on the wire, held where ``cancelAll()`` can reach them from outside the
/// tasks that sent them — a refresh runs in a task of the client's own, which no caller's
/// cancellation reaches.
final class InFlightRequests: Sendable {
  private typealias Send = Task<(Data, HTTPURLResponse), any Error>

  private let state = Mutex<(cancelled: Bool, sends: [UUID: Send])>((false, [:]))

  /// Runs `send` until it answers, and cancels it with the caller. Throws `CancellationError`
  /// once ``cancelAll()`` has run, whether the request was on the wire then or sent after.
  func run(_ send: @escaping @Sendable () async throws -> (Data, HTTPURLResponse)) async throws
    -> (Data, HTTPURLResponse)
  {
    let id = UUID()
    let task: Send? = state.withLock { state in
      guard !state.cancelled else { return nil }
      let task = Send { try await send() }
      state.sends[id] = task
      return task
    }
    guard let task else { throw CancellationError() }
    defer { state.withLock { _ = $0.sends.removeValue(forKey: id) } }
    do {
      return try await withTaskCancellationHandler {
        try await task.value
      } onCancel: {
        task.cancel()
      }
    } catch {
      if state.withLock({ $0.cancelled }) { throw CancellationError() }
      throw error
    }
  }

  /// Cancels every request on the wire, and every one sent after.
  func cancelAll() {
    let sends = state.withLock { state in
      state.cancelled = true
      defer { state.sends = [:] }
      return Array(state.sends.values)
    }
    for send in sends { send.cancel() }
  }
}
