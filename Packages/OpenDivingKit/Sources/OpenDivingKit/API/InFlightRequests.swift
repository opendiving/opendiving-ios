import Foundation
import Synchronization

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// One client's requests on the wire, held where ``cancelAll()`` can reach them from outside the
/// tasks that sent them — a refresh runs in a task of the client's own, which no caller's
/// cancellation reaches.
final class InFlightRequests: Sendable {
  private let state = Mutex<(cancelled: Bool, sends: [UUID: @Sendable () -> Void])>((false, [:]))

  /// Runs `send` until it answers, and cancels it with the caller. Throws `CancellationError`
  /// once ``cancelAll()`` has run, whether the request was on the wire then or sent after.
  func run<Answer: Sendable>(_ send: @escaping @Sendable () async throws -> Answer) async throws
    -> Answer
  {
    let id = UUID()
    let task: Task<Answer, any Error>? = state.withLock { state in
      guard !state.cancelled else { return nil }
      let task = Task { try await send() }
      state.sends[id] = { task.cancel() }
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
    for cancel in sends { cancel() }
  }
}
