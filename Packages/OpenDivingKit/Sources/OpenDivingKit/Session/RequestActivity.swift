import Foundation

/// How many of the session's requests are on the wire, for whatever waits until the app has
/// stopped loading. Uploads are not counted: a file syncing behind the screens is not a screen
/// loading.
@MainActor
public final class RequestActivity {
  public private(set) var inFlight = 0
  private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]

  public init() {}

  func begin() {
    inFlight += 1
  }

  func end() {
    inFlight -= 1
    guard inFlight == 0 else { return }
    let idle = waiters
    waiters = [:]
    for waiter in idle.values { waiter.resume() }
  }

  /// Returns once no request is on the wire — at once when none is — or once the task is
  /// cancelled.
  public func untilIdle() async {
    guard inFlight > 0 else { return }
    let id = UUID()
    await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        if inFlight == 0 || Task.isCancelled {
          continuation.resume()
        } else {
          waiters[id] = continuation
        }
      }
    } onCancel: {
      Task { @MainActor in self.waiters.removeValue(forKey: id)?.resume() }
    }
  }
}
