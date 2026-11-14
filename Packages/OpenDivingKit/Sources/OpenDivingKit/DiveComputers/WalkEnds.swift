import Foundation

/// When the last walk from each paired computer ended, and how many walks in a row before it broke
/// off, kept on the phone for every process: a connection inside the wait of one starts no walk,
/// though the watch's own visits are the process's alone.
struct WalkEnds: Sendable {
  struct End: Codable, Equatable, Sendable {
    var at: Date
    /// The automatic walks in a row, this one included, that ended in failure.
    var breakOffs: Int

    /// How long after ``at`` the computer's next walk may start.
    var wait: Int { DiveComputerWatch.revisitWait(afterBreakOffs: breakOffs) }

    init(at: Date, breakOffs: Int) {
      self.at = at
      self.breakOffs = breakOffs
    }

    /// An earlier build wrote each end as its date alone.
    init(from decoder: any Decoder) throws {
      if let at = try? decoder.singleValueContainer().decode(Date.self) {
        self.init(at: at, breakOffs: 0)
        return
      }
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.init(
        at: try container.decode(Date.self, forKey: .at),
        breakOffs: try container.decode(Int.self, forKey: .breakOffs))
    }
  }

  let file: URL

  init(applicationSupport: URL) {
    file = applicationSupport.appendingPathComponent("dive-computer-walks.json", isDirectory: false)
  }

  func read() -> [String: End] {
    guard let data = try? Data(contentsOf: file) else { return [:] }
    // Plain coding: a key strategy would rewrite the records' names, which are the keys.
    return (try? JSONDecoder().decode([String: End].self, from: data)) ?? [:]
  }

  /// A walk that broke off adds one to its computer's row; any other end ends the row.
  func ended(_ record: String, at moment: Date, brokeOff: Bool) {
    var ends = read()
    let row = brokeOff ? (ends[record]?.breakOffs ?? 0) + 1 : 0
    ends[record] = End(at: moment, breakOffs: row)
    guard let data = try? JSONEncoder().encode(ends) else { return }
    try? FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? data.write(to: file, options: .atomic)
  }
}
