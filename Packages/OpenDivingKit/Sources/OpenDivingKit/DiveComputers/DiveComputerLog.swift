import Foundation
import Synchronization

/// The last download's log: one file the phone keeps, replaced when a download starts, each line
/// timestamped. It holds what the walk and libdivecomputer say about the transfers — no account
/// data — so it is the phone's, not an account's, and outlives a sign-out. Bounded: once
/// `limit` bytes are written, later lines are dropped.
public final class DiveComputerLog: Sendable {
  public let file: URL
  private let limit: Int
  private let now: @Sendable () -> Date
  private let state = Mutex<(handle: FileHandle?, written: Int)>((nil, 0))

  public init(file: URL, limit: Int = 1 << 20, now: @escaping @Sendable () -> Date = Date.init) {
    self.file = file
    self.limit = limit
    self.now = now
  }

  /// Replaces the file with an empty one, which the next lines go to.
  public func start() {
    state.withLock { state in
      try? state.handle?.close()
      state = (nil, 0)
      let directory = file.deletingLastPathComponent()
      try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      guard (try? Data().write(to: file, options: .atomic)) != nil else { return }
      state.handle = try? FileHandle(forWritingTo: file)
    }
  }

  /// Appends `line` after the time, to the millisecond; nothing before ``start()`` or past the
  /// limit.
  public func write(_ line: String) {
    let stamped = Data("\(Self.stamp(now())) \(line)\n".utf8)
    state.withLock { state in
      guard let handle = state.handle else { return }
      guard state.written + stamped.count <= limit else {
        try? handle.write(contentsOf: Data("\(Self.stamp(now())) limit reached\n".utf8))
        try? handle.close()
        state.handle = nil
        return
      }
      guard (try? handle.write(contentsOf: stamped)) != nil else { return }
      state.written += stamped.count
    }
  }

  static func stamp(_ date: Date) -> String {
    date.formatted(
      .iso8601.year().month().day().dateTimeSeparator(.standard)
        .time(includingFractionalSeconds: true).timeZone(separator: .omitted))
  }
}
