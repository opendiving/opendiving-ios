import Foundation
import Testing

@testable import OpenDivingKit

struct DiveComputerLogTests {
  private func file() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
      .appendingPathComponent("dive-computer.log")
  }

  private let instant = Date(timeIntervalSince1970: 1_730_000_000.25)

  private func lines(_ url: URL) throws -> [String] {
    let text = try String(contentsOf: url, encoding: .utf8)
    return text.split(separator: "\n").map(String.init)
  }

  @Test func eachLineCarriesTheTimeToTheMillisecond() throws {
    let url = file()
    let instant = instant
    let log = DiveComputerLog(file: url, now: { instant })
    log.start()
    log.write("listing DC_STATUS_SUCCESS 12 ms")
    let written: [String] = try lines(url)
    #expect(written == ["2024-10-27T03:33:20.250Z listing DC_STATUS_SUCCESS 12 ms"])
  }

  @Test func aStartReplacesTheLastDownloadsLines() throws {
    let url = file()
    let log = DiveComputerLog(file: url)
    log.start()
    log.write("first")
    log.start()
    log.write("second")
    let written: [String] = try lines(url)
    #expect(written.count == 1)
    #expect(written.first?.hasSuffix(" second") == true)
  }

  @Test func nothingIsWrittenBeforeAStart() {
    let url = file()
    DiveComputerLog(file: url).write("early")
    #expect(!FileManager.default.fileExists(atPath: url.path))
  }

  @Test func linesPastTheLimitAreDropped() throws {
    let url = file()
    let log = DiveComputerLog(file: url, limit: 100)
    log.start()
    for index in 0..<10 { log.write("line \(index)") }
    let written: [String] = try lines(url)
    #expect(written.count < 10)
    #expect(written.last?.hasSuffix(" limit reached") == true)
  }

  @Test func theWatchLogAppendsAcrossProcesses() throws {
    let url = file()
    DiveComputerWatchLog(file: url).write("launch by the user")
    DiveComputerWatchLog(file: url).write("launch by iOS, restoring watch")
    let written: [String] = try lines(url)
    #expect(written.count == 2)
    #expect(written.last?.hasSuffix(" launch by iOS, restoring watch") == true)
  }

  @Test func theWatchLogDropsItsOlderHalfAtTheLimit() throws {
    let url = file()
    let log = DiveComputerWatchLog(file: url, limit: 400)
    for index in 0..<40 { log.write("line \(index)") }
    let written: [String] = try lines(url)
    let size = try #require(
      try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int)
    #expect(size <= 400)
    #expect(written.last?.hasSuffix(" line 39") == true)
    #expect(written.first?.hasSuffix(" line 0") == false)
    // Every line kept is whole.
    #expect(written.allSatisfy { $0.contains("Z line ") })
  }
}
