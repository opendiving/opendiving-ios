import Foundation
import OpenDivingKit

/// Writes the watch's zone resources, as fetched, under Documents/NauticZoneCapture, for the
/// decode to be written against; the walk then ends before any dive is read.
nonisolated enum NauticZoneCapture {
  static let isEnabled = true

  static func write(_ resources: [NauticZoneResources.Resource], computer: FoundComputer) {
    let fileManager = FileManager.default
    guard
      let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
    else { return }
    let now = Date()
    let stamp = ISO8601DateFormatter().string(from: now).replacingOccurrences(of: ":", with: "")
    let folder = documents.appendingPathComponent("NauticZoneCapture", isDirectory: true)
      .appendingPathComponent(stamp, isDirectory: true)
    try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)

    let zone = TimeZone.current
    var summary = [
      "computer: \(computer.name)",
      "captured: \(ISO8601DateFormatter().string(from: now))",
      "phone zone: \(zone.identifier), offset \(zone.secondsFromGMT(for: now)) s,"
        + " daylight saving \(zone.isDaylightSavingTime(for: now))",
    ]
    for resource in resources {
      let name = resource.path.split(separator: "/").joined(separator: "_")
      summary.append(line(resource.path, "fetch", resource.fetched))
      if case .success(let data) = resource.fetched {
        try? data.write(to: folder.appendingPathComponent(name + ".fetch.bin"))
      }
      if let raw = resource.raw {
        summary.append(line(resource.path, "fetchRaw", raw))
        if case .success(let data) = raw {
          try? data.write(to: folder.appendingPathComponent(name + ".raw.bin"))
        }
      }
    }
    try? (summary.joined(separator: "\n") + "\n").write(
      to: folder.appendingPathComponent("summary.txt"), atomically: true, encoding: .utf8)
  }

  private static func line(
    _ path: String, _ call: String, _ result: Result<Data, NauticZoneResources.Failure>
  ) -> String {
    switch result {
    case .success(let data):
      "\(path) \(call): \(data.count) bytes: "
        + data.map { String(format: "%02X", $0) }.joined(
          separator: " ")
    case .failure(let failure):
      "\(path) \(call): failed, \(failure.description)"
    }
  }
}
