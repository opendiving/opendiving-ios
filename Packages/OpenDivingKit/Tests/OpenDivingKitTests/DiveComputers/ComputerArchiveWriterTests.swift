import Foundation
import Testing

@testable import OpenDivingKit

/// The archive writer against the goldens — which CI validates with `divejson validate` — and
/// the invariants that keep a download importable and true to what the computer reported.
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
      written.download
        == InboxDownload(
          computers: [
            .init(
              family: .shearwaterPetrel, vendor: "Shearwater", product: "Perdix 3",
              serial: "D9772626", dives: 2)
          ], downloadedAt: F.moment))

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

  @Test func nothingIsInventedAndTheProducerKeySitsOnTheRecordingAlone() throws {
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
        for file in recording["source_files"]?.arrayValue ?? [] {
          #expect(file["extensions"] == nil)
        }
      }
    }
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

  @Test func salinityIsTheSettingAndItsDensityTravelsBesideIt() throws {
    defer { try? FileManager.default.removeItem(at: folder) }
    let perdix = try document(try perdixArchive().url).json["dives"]?.arrayValue?.first
    let recording = try #require(perdix?["recordings"]?.arrayValue?.first)
    #expect(recording["salinity"]?.stringValue == "en13319")
    #expect(recording["extensions"]?["opendiving"]?["salinity_density"] == .integer(1020))
    let ocean = try document(try oceanArchive().url).json["dives"]?.arrayValue?.first
    #expect(ocean?["recordings"]?.arrayValue?.first?["salinity"]?.stringValue == "salt")
  }

  /// Heart rate is a profile channel and rides nowhere else. A 0 is a sensor's absent-marker,
  /// below the format's floor of 1, so it writes a gap rather than a reading.
  @Test func heartRateRidesTheProfileAndAZeroWritesNothing() throws {
    defer { try? FileManager.default.removeItem(at: folder) }
    var dive = F.perdixDive
    dive.samples[0].heartRate = 0
    var download = F.perdixDownload
    download[0] = DownloadedDive(
      identity: F.perdix, fingerprint: F.fingerprint(3), bytes: Data("perdix dive 3".utf8),
      reading: .dive(dive))
    let written = try writer.write(
      .init(
        identity: F.perdix, dives: download, moment: F.moment, zone: F.helsinki,
        instantZone: nil), into: folder)
    let dives = try #require(try document(written.url).json["dives"]?.arrayValue)
    let recording = try #require(dives[0]["recordings"]?.arrayValue?.first)
    #expect(
      recording["profile"]?["heart_rate"]
        == .object(["times": .array([.integer(10_000)]), "values": .array([.integer(92)])]))
    #expect(recording["extensions"]?["opendiving"]?["heart_rate"] == nil)
    // The dive whose computer reported none writes the member nowhere.
    #expect(!dives[1].text.contains("heart_rate"))
  }

  /// A sample before the start — a GPS fix the watch took before it — is written nowhere, and
  /// the profile's duration is the last moment at or after it.
  @Test func aSampleBeforeTheStartIsLeftOut() throws {
    defer { try? FileManager.default.removeItem(at: folder) }
    var dive = F.oceanDownload[0].dive!
    var early = ComputerDive.Sample(time: -1834)
    early.location = .init(latitude: 60.1, longitude: 24.9)
    dive.samples = [
      early, .init(time: -804, temperature: 11), .init(time: 0, depth: 0.3),
      .init(time: 1000, depth: 1.2),
    ]
    var download = F.oceanDownload
    download[0] = DownloadedDive(
      identity: F.ocean, fingerprint: F.fingerprint(0x12), bytes: Data("ocean after".utf8),
      reading: .dive(dive))
    let written = try writer.write(
      .init(
        identity: F.ocean, dives: download, moment: F.moment, zone: F.helsinki,
        instantZone: F.helsinki), into: folder)
    let dives = try #require(try document(written.url).json["dives"]?.arrayValue)
    let recording = try #require(dives[0]["recordings"]?.arrayValue?.first)
    #expect(recording["profile"]?["duration"] == .integer(1000))
    #expect(recording["profile"]?["temperature"] == nil)
    #expect(!dives[0].text.contains("positions"))
    #expect(!dives[0].text.contains("4294"))
  }

  // MARK: - The union

  @Test func theUnionHoldsEachDiveAndEachOriginalOnce() throws {
    defer { try? FileManager.default.removeItem(at: folder) }
    let first = try perdixArchive()
    let held = folder.appendingPathComponent("held", isDirectory: true)
    try FileManager.default.createDirectory(at: held, withIntermediateDirectories: true)
    let firstURL = held.appendingPathComponent("first.zip")
    try FileManager.default.moveItem(at: first.url, to: firstURL)
    let second = try perdixArchive()
    let ocean = try oceanArchive()

    let union = try writer.unite(
      [(ocean.url, ocean.download), (second.url, second.download), (firstURL, first.download)],
      moment: F.moment.addingTimeInterval(600), zone: F.helsinki,
      into: folder.appendingPathComponent("union", isDirectory: true))

    #expect(union.url.lastPathComponent == "dive-computers_2026-10-25T0930.zip")
    #expect(union.download.computers.map(\.dives) == [2, 2])
    #expect(
      DiveComputerText.inboxRow(union.download, in: F.helsinki)
        == "4 dives from Suunto Ocean and Shearwater Perdix 3, downloaded 25 October")
    let reader = try ZipReader(union.url)
    let json = try document(union.url).json
    let uuids = try #require(json["dives"]?.arrayValue).compactMap { $0["uuid"]?.stringValue }
    #expect(uuids.count == 4)
    #expect(Set(uuids).count == 4)
    #expect(reader.entries.count == 1 + 4 + 1)
    #expect(Set(reader.entries.map(\.name)).count == reader.entries.count)

    let alone = try writer.unite(
      [(second.url, second.download), (firstURL, first.download)], moment: F.moment,
      zone: F.helsinki, into: folder.appendingPathComponent("alone", isDirectory: true))
    #expect(alone.url.lastPathComponent == "shearwater-perdix-3_D9772626_2026-10-25T0920.zip")
    #expect(alone.download.dives == 2)
  }
}
