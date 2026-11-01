import Foundation
import Observation

/// The coral splash over a cold start, as the web shows one over a document's first load. It
/// stays up for ``minimum`` at least, then until the session has no request on the wire —
/// whatever the first screen asked for — and has had none for ``settle``, which catches a
/// request sent on the heels of another's answer. Never past ``ceiling``: a request waits up to
/// a minute for a route, and the screens under the splash already show what the phone kept.
@MainActor
@Observable
public final class LaunchSplash {
  public typealias Sleep = @Sendable (Duration) async throws -> Void

  public private(set) var isShowing = true

  @ObservationIgnored private let minimum: Duration
  @ObservationIgnored private let settle: Duration
  @ObservationIgnored private let ceiling: Duration
  @ObservationIgnored private let sleep: Sleep

  /// `sleep` stands in for the clock in a test.
  public init(
    minimum: Duration = .milliseconds(500),
    settle: Duration = .milliseconds(150),
    ceiling: Duration = .seconds(5),
    sleep: @escaping Sleep = { try await Task.sleep(for: $0) }
  ) {
    self.minimum = minimum
    self.settle = settle
    self.ceiling = ceiling
    self.sleep = sleep
  }

  /// Takes the splash down once `activity` has gone quiet, timed from this call.
  public func run(_ activity: RequestActivity) async {
    guard isShowing else { return }
    try? await sleep(minimum)
    guard !Task.isCancelled else { return }
    await withTaskGroup(of: Void.self) { group in
      group.addTask { await self.quiet(activity) }
      group.addTask { [sleep, ceiling, minimum] in try? await sleep(ceiling - minimum) }
      await group.next()
      group.cancelAll()
    }
    isShowing = false
  }

  private func quiet(_ activity: RequestActivity) async {
    repeat {
      await activity.untilIdle()
      try? await sleep(settle)
    } while activity.inFlight > 0 && !Task.isCancelled
  }
}
