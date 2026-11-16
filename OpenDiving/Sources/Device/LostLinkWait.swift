import Synchronization

/// What a walk the diver started reads while it waits for a computer that dropped the link: whether
/// the app is in the foreground, where the walk reopens the computer itself, and whether the
/// computer has since connected to the watch's request, which a walk behind waits for instead.
/// Set on the main actor by the link, read by the walk on the session's queue.
nonisolated final class LostLinkWait: Sendable {
  private let front = Atomic(true)
  private let back = Atomic(false)

  var inForeground: Bool { front.load(ordering: .relaxed) }

  func setForeground(_ foreground: Bool) { front.store(foreground, ordering: .relaxed) }

  /// The computer connected again: the walk reopens it at once.
  func returned() { back.store(true, ordering: .relaxed) }

  /// Whether the computer connected again since the last call, clearing it.
  func takeReturn() -> Bool { back.exchange(false, ordering: .relaxed) }
}
