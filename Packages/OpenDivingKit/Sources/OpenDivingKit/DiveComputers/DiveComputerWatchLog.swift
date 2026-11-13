import Foundation
import Synchronization

/// The watch's log: one file the phone keeps across launches, appended to, each line timestamped
/// as the download's log is. Like that log it names no account, so it is the phone's. Bounded:
/// once a line would take it past `limit` bytes, the older half is dropped.
public final class DiveComputerWatchLog: Sendable {
  public let file: URL
  private let limit: Int
  private let now: @Sendable () -> Date
  private let handle = Mutex<FileHandle?>(nil)

  public init(file: URL, limit: Int = 1 << 20, now: @escaping @Sendable () -> Date = Date.init) {
    self.file = file
    self.limit = limit
    self.now = now
  }

  /// Appends `line` after the time, to the millisecond.
  public func write(_ line: String) {
    let stamped = Data("\(DiveComputerLog.stamp(now())) \(line)\n".utf8)
    handle.withLock { handle in
      if handle == nil { handle = open() }
      guard let current = handle, let end = try? current.seekToEnd() else { return }
      if Int(end) + stamped.count > limit {
        try? current.close()
        handle = nil
        trim(keeping: limit / 2)
        handle = open()
      }
      guard let current = handle else { return }
      _ = try? current.seekToEnd()
      try? current.write(contentsOf: stamped)
    }
  }

  private func open() -> FileHandle? {
    if !FileManager.default.fileExists(atPath: file.path) {
      try? FileManager.default.createDirectory(
        at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
      guard FileManager.default.createFile(atPath: file.path, contents: nil) else { return nil }
    }
    return try? FileHandle(forWritingTo: file)
  }

  /// Keeps the last `bytes` of the file, from the first whole line in them.
  private func trim(keeping bytes: Int) {
    guard let data = try? Data(contentsOf: file) else { return }
    var tail = data.suffix(bytes)
    if tail.count < data.count, let newline = tail.firstIndex(of: UInt8(ascii: "\n")) {
      tail = tail[tail.index(after: newline)...]
    }
    try? Data(tail).write(to: file, options: .atomic)
  }
}
