import Foundation

/// A folder of JSON files, one value each, decoded one by one so that a file this build cannot
/// read is kept rather than taking the others down with it. Nothing here removes or
/// overwrites a file it could not decode: writes go to a file of the value's own name, and a
/// removal names the file.
struct KeptFolder<Value: Codable>: Sendable {
  let url: URL

  /// The readable values by file name, and the names of the files that would not decode.
  func load() -> (values: [(name: String, value: Value)], unreadable: [String]) {
    let names =
      ((try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? [])
      .filter { $0.hasSuffix(".json") }.sorted()
    var values: [(String, Value)] = []
    var unreadable: [String] = []
    let decoder = APICoding.decoder()
    for name in names {
      if let data = try? Data(contentsOf: file(name)),
        let value = try? decoder.decode(Value.self, from: data)
      {
        values.append((name, value))
      } else {
        unreadable.append(name)
      }
    }
    return (values, unreadable)
  }

  func read(_ name: String) -> Value? {
    guard let data = try? Data(contentsOf: file(name)) else { return nil }
    return try? APICoding.decoder().decode(Value.self, from: data)
  }

  func write(_ value: Value, name: String) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    try APICoding.encoder().encode(value).write(to: file(name), options: .atomic)
  }

  func remove(_ name: String) {
    try? FileManager.default.removeItem(at: file(name))
  }

  func contains(_ name: String) -> Bool {
    FileManager.default.fileExists(atPath: file(name).path)
  }

  static func name(for id: UUID) -> String {
    id.uuidString.lowercased() + ".json"
  }

  private func file(_ name: String) -> URL {
    url.appendingPathComponent(name, isDirectory: false)
  }
}
