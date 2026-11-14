import Foundation
import Testing

@testable import OpenDivingKit

/// The archive writer against the goldens — which CI validates with `divejson validate` — and
/// the invariants that keep a download importable and true to what the reader returned.
struct ComputerArchiveWriterTests {
  private typealias F = DiveComputerFixtures

  private let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
    "ComputerArchiveWriterTests-\(UUID().uuidString)", isDirectory: true)
  private let writer = ComputerArchiveWriter(generator: DiveComputerFixtures.generator)

  private func perdixArchive() throws -> ComputerArchiveWriter.Written {
    try writer.write(
      .init(
        identity: F.perdix, dives: F.perdixDownload, moment: F.moment, zone: F.helsinki,
        instantZone: nil), into: folder)
  }

  private func oceanArchive(zone: TimeZone? = DiveComputerFixtures.helsinki) throws
    -> ComputerArchiveWriter.Written
  {
    try writer.write(
      .init(
        identity: F.ocean, dives: F.oceanDownload, moment: F.moment, zone: F.helsinki,
        instantZone: zone), into: folder)
  }

  private func document(_ url: URL) throws -> (text: String, json: ArchiveJSON) {
    let reader = try ZipReader(url)
    let entry = try #require(reader.entries.first { $0.name == "logbook.divejson" })
    let data = try reader.read(entry)
    return (String(decoding: data, as: UTF8.self), try #require(ArchiveJSON.parse(data)))
  }

  /// Compares with `Fixtures/DiveComputers/<name>.divejson`, byte for byte. On a mismatch the
  /// document written is left beside the test's folder to diff against.
  private func expectGolden(_ text: String, _ name: String) throws {
    let url = try #require(
      Bundle.module.url(
        forResource: name, withExtension: "divejson", subdirectory: "Fixtures/DiveComputers"))
    let golden = try String(contentsOf: url, encoding: .utf8)
    if golden != text + "\n" {
      let actual = FileManager.default.temporaryDirectory.appendingPathComponent(
        "\(name).actual.divejson")
      try (text + "\n").write(to: actual, atomically: true, encoding: .utf8)
      Issue.record("\(name) differs from its golden; the document written is at \(actual.path)")
    }
  }

  @Test func thePerdixDownloadReproducesItsGolden() throws {
    defer { try? FileManager.default.removeItem(at: folder) }
    let written = try perdixArchive()
    try expectGolden(try document(written.url).text, "perdix-3-download")
  }

  @Test func theOceanDownloadReproducesItsGolden() throws {
    defer { try? FileManager.default.removeItem(at: folder) }
    let written = try oceanArchive()
    try expectGolden(try document(written.url).text, "ocean-download")
  }

  @Test func theArchiveIsNamedAndHoldsEveryOriginalWithItsDigest() throws {
    defer { try? FileManager.default.removeItem(at: folder) }
    let written = try perdixArchive()
    #expect(written.url.lastPathComponent == "shearwater-perdix-3_D9772626_2026-10-25T0920.zip")
    #expect(
      written.summary
        == DownloadSummary(
          computers: [
            .init(
              family: .shearwaterPetrel, vendor: "Shearwater", product: "Perdix 3",
              serial: "D9772626", dives: 2)
          ], downloadedAt: F.moment))
    #expect(
      written.dives
        == F.perdixDownload.compactMap { dive in
          dive.dive.map { _ in
            DiveComputerArchive.diveUUID(dive.identity, fingerprint: dive.fingerprint)
          }
        })

    let reader = try ZipReader(written.url)
    #expect(
      reader.entries.map(\.name) == [
        "logbook.divejson", "files/shearwater-perdix-3_D9772626_2026-10-25T0914.bin",
        "files/shearwater-perdix-3_D9772626_2026-10-24T1502.bin",
        "files/shearwater-perdix-3_D9772626_01a00bcd.bin",
      ])
    let json = try document(written.url).json
    let dives = try #require(json["dives"]?.arrayValue)
    #expect(dives.count == 2)
    for (dive, entry) in zip(dives, reader.entries.dropFirst()) {
      let file = try #require(
        dive["recordings"]?.arrayValue?.first?["source_files"]?.arrayValue?.first)
      #expect(file["archive_path"]?.stringValue == entry.name)
      #expect(file["original_filename"]?.stringValue == String(entry.name.dropFirst(6)))
      #expect(file["content_type"]?.stringValue == "application/octet-stream")
      let bytes = try reader.read(entry)
      #expect(file["sha256"]?.stringValue == SHA256Digest.hex(bytes))
      #expect(file["byte_size"]?.integerValue == bytes.count)
    }
    // The refused dive's bytes travel, named by its fingerprint, and no dive names them.
    #expect(try reader.read(reader.entries[3]) == Data("perdix dive 1".utf8))
  }

  @Test func nothingIsInventedAndTheProducerKeySitsOnTheStoredFileAlone() throws {
    defer { try? FileManager.default.removeItem(at: folder) }
    for written in [try perdixArchive(), try oceanArchive()] {
      let json = try document(written.url).json
      #expect(json["diver"] == nil)
      #expect(json["extensions"] == nil)
      #expect(json["generator"]?["name"]?.stringValue == "OpenDiving for iOS")
      for dive in try #require(json["dives"]?.arrayValue) {
        for absent in ["number", "water_type", "bottom_temperature", "extensions"] {
          #expect(dive[absent] == nil)
        }
        let recording = try #require(dive["recordings"]?.arrayValue?.first)
        #expect(recording["device"]?["brand"] == nil)
        #expect(recording["extensions"] == nil)
        for file in recording["source_files"]?.arrayValue ?? [] {
          #expect(file["extensions"]?["opendiving"]?["parser_key"] == .string("libdivecomputer"))
        }
      }
    }
  }

  /// The tag is what `opendiving-api` reads the original again with: the descriptor, and the
  /// fallback start the reader was given, as an instant in UTC.
  @Test func theOriginalIsTaggedWithWhatReadsItAgain() throws {
    defer { try? FileManager.default.removeItem(at: folder) }
    func tags(_ written: ComputerArchiveWriter.Written) throws -> [ArchiveJSON?] {
      try #require(try document(written.url).json["dives"]?.arrayValue).map {
        $0["recordings"]?.arrayValue?.first?["source_files"]?.arrayValue?.first?["extensions"]?[
          "opendiving"]
      }
    }
    let descriptor: ArchiveJSON = .object([
      "vendor": .string("Shearwater"), "product": .string("Perdix 3"), "model": .integer(14),
    ])
    #expect(
      try tags(try perdixArchive())
        == Array(
          repeating: .object(["parser_key": .string("libdivecomputer"), "descriptor": descriptor]),
          count: 2))
    #expect(
      try tags(try oceanArchive()).first
        == .object([
          "parser_key": .string("libdivecomputer"),
          "descriptor": .object([
            "vendor": .string("Suunto"), "product": .string("Ocean"), "model": .integer(1),
          ]),
          "fallback_start": .string("2026-10-26T10:00:00+00:00"),
        ]))
  }

  /// The reader's dive is written as it returned it, but for the uuid and the start, which are
  /// the host's, and the device and the stored file the recording gains.
  @Test func theReadersMembersReachTheDocumentUnchanged() throws {
    defer { try? FileManager.default.removeItem(at: folder) }
    let written = try document(try perdixArchive().url).json
    guard case .object(var dive)? = written["dives"]?.arrayValue?.first,
      case .object(var recording)? = dive["recordings"]?.arrayValue?.first
    else { throw DiveComputerArchiveError.noZone }
    recording["device"] = nil
    recording["source_files"] = nil
    dive["recordings"] = .array([.object(recording)])
    var read = F.perdixDive.body
    #expect(dive["uuid"] != read["uuid"])
    for key in ["uuid", "started_at"] {
      dive[key] = nil
      read[key] = nil
    }
    #expect(dive == read)
  }

  @Test func theDeviceIsSpelledAsEachFamilysExportsSpellIt() throws {
    defer { try? FileManager.default.removeItem(at: folder) }
    let perdix = try document(try perdixArchive().url).json["dives"]?.arrayValue?.first
    let ocean = try document(try oceanArchive().url).json["dives"]?.arrayValue?.first
    // Shearwater Cloud's UDDF of the same Perdix 3, and the Suunto app's FIT of the same Ocean.
    #expect(
      perdix?["recordings"]?.arrayValue?.first?["device"]
        == .object([
          "model": .string("Perdix 3"), "serial": .string("D9772626"), "firmware": .string("93"),
        ]))
    #expect(
      ocean?["recordings"]?.arrayValue?.first?["device"]
        == .object([
          "model": .string("Suunto Ocean"), "serial": .string("253810000400"),
          "firmware": .string("2.4.6"),
        ]))
  }

  @Test func startsAreTheComputersResolvedOnce() throws {
    defer { try? FileManager.default.removeItem(at: folder) }
    let perdix = try #require(try document(try perdixArchive().url).json["dives"]?.arrayValue)
    #expect(
      perdix.map { $0["started_at"]?.stringValue } == [
        "2026-10-25T09:14:07", "2026-10-24T15:02:00+03:00",
      ])
    // Each instant in Helsinki's offset at that instant: summer time before the night of the
    // 25th, winter time after.
    let ocean = try #require(try document(try oceanArchive().url).json["dives"]?.arrayValue)
    #expect(
      ocean.map { $0["started_at"]?.stringValue } == [
        "2026-10-26T12:00:00+02:00", "2026-10-24T13:00:00+03:00",
      ])
    #expect(throws: DiveComputerArchiveError.noZone) { try oceanArchive(zone: nil) }
  }

  @Test func aDiveDownloadedTwiceKeepsItsUUID() throws {
    defer { try? FileManager.default.removeItem(at: folder) }
    let first = try document(try perdixArchive().url).json
    try FileManager.default.removeItem(at: folder)
    let again = try document(try perdixArchive().url).json
    #expect(
      first["dives"]?.arrayValue?.map { $0["uuid"] }
        == again["dives"]?.arrayValue?.map { $0["uuid"] })
    let uuid = try #require(first["dives"]?.arrayValue?.first?["uuid"]?.stringValue)
    #expect(UUID(uuidString: uuid).map { $0.uuidString.lowercased() } == uuid)
    #expect(uuid.dropFirst(14).first == "5")
  }
}
