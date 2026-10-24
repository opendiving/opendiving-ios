import Foundation
import Testing

/// Every formatter pins the web's `en-US` by reading no locale at all: a `DateFormatter`,
/// a `NumberFormatter` or `.formatted()` takes the phone's region by default, and would
/// print other month names and another decimal separator than every test here asserts.
/// Swift cannot switch the process's locale for a second run of the tables, so the guard
/// is that nothing under `Formatting/`, `DiveForm/` or `RecordForms/` reaches for one — the
/// forms read a typed decimal by looking at two characters, not at the region.
struct LocaleIndependenceTests {
  @Test(arguments: ["Formatting", "DiveForm", "RecordForms"])
  func readsNoLocale(_ folder: String) throws {
    let sources = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Sources/OpenDivingKit/" + folder)
    let files = try FileManager.default.contentsOfDirectory(atPath: sources.path)
      .filter { $0.hasSuffix(".swift") }
    #expect(!files.isEmpty)
    let forbidden = ["Locale", "DateFormatter", "NumberFormatter", ".formatted(", "String(format:"]
    for file in files {
      let code = try String(contentsOf: sources.appendingPathComponent(file), encoding: .utf8)
        .split(separator: "\n")
        .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        .joined(separator: "\n")
      for word in forbidden {
        #expect(!code.contains(word), "\(folder)/\(file) uses \(word)")
      }
    }
  }
}
