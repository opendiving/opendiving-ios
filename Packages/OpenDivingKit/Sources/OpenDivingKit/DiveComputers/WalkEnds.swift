import Foundation

/// When the last walk from each paired computer ended, kept on the phone for every process: a
/// connection inside the revisit delay of one starts no walk, though the watch's own visits are
/// the process's alone.
struct WalkEnds: Sendable {
  let file: URL

  init(applicationSupport: URL) {
    file = applicationSupport.appendingPathComponent("dive-computer-walks.json", isDirectory: false)
  }

  func read() -> [String: Date] {
    guard let data = try? Data(contentsOf: file) else { return [:] }
    // Plain coding: a key strategy would rewrite the records' names, which are the keys.
    return (try? JSONDecoder().decode([String: Date].self, from: data)) ?? [:]
  }

  func ended(_ record: String, at moment: Date) {
    var ends = read()
    ends[record] = moment
    guard let data = try? JSONEncoder().encode(ends) else { return }
    try? FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? data.write(to: file, options: .atomic)
  }
}
