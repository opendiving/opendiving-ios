import Foundation
import OpenDivingKit
import Testing

@testable import OpenDiving

/// The reader as the app links it — `libdivejson` against libdc-swift's libdivecomputer — over
/// two real originals: one deco dive recorded on a Perdix 3 and an Ocean worn together. Each
/// `.divejson` beside its `.bin` is the document the reader's own suite expects, so a dive read
/// here that differs from it is a link to a libdivecomputer the reader was not built for.
struct LibDCDiveParserTests {
  private final class Token {}

  private static let perdix = DiveComputerIdentity(
    family: .shearwaterPetrel, vendor: "Shearwater", product: "Perdix 3", serial: "D9772626",
    firmware: nil, familyNumber: 0, modelNumber: 14)
  private static let ocean = DiveComputerIdentity(
    family: .suuntoNautic, vendor: "Suunto", product: "Ocean", serial: "253810000400",
    firmware: nil, familyNumber: 0, modelNumber: 1)

  /// The Ocean fixture's fingerprint: its start, 2026-10-26T12:01:49Z, as the watch keys it.
  private static let oceanFingerprint = Data([0x2D, 0x41, 0xDF, 0x6A])

  private func fixture(_ name: String, _ ext: String) throws -> Data {
    let url = try #require(Bundle(for: Token.self).url(forResource: name, withExtension: ext))
    return try Data(contentsOf: url)
  }

  /// The dive the reader's own suite expects, as the Kit takes it.
  private func expected(_ name: String, identity: DiveComputerIdentity, fallbackStart: Date?)
    throws -> ComputerDive
  {
    let document = try JSONSerialization.jsonObject(with: try fixture(name, "divejson"))
    let dive = try #require(((document as? [String: Any])?["dives"] as? [Any])?.first)
    return try #require(
      ComputerDive(
        json: try JSONSerialization.data(withJSONObject: dive),
        logsInstants: identity.family.logsInstants, fallbackStart: fallbackStart))
  }

  @Test func thePerdixOriginalReadsAsTheReaderExpects() throws {
    let name = "shearwater-perdix-3_D9772626_2026-10-26T1503"
    let parsed = LibDCDiveParser.parse(
      try fixture(name, "bin"), identity: Self.perdix, fallbackStart: nil)
    let expected = try expected(name, identity: Self.perdix, fallbackStart: nil)
    #expect(parsed == .dive(expected))
    let clock = LocalDateTime(
      date: CalendarDate(year: 2026, month: 10, day: 26)!, hour: 15, minute: 3, second: 23)
    #expect(expected.start == .wallClock(try #require(clock), utcOffsetSeconds: nil))
  }

  /// The Ocean's log holds a GPS fix, so its start is the parser's — an instant, logged in UTC —
  /// and the fallback the walk passes rides along for the stored file's tag.
  @Test func theOceanOriginalReadsAsTheReaderExpects() throws {
    let name = "suunto-ocean_253810000400_2026-10-26T1501"
    let fallback = LibDCDiveParser.fingerprintStart(Self.oceanFingerprint)
    let parsed = LibDCDiveParser.parse(
      try fixture(name, "bin"), identity: Self.ocean, fallbackStart: fallback)
    let expected = try expected(name, identity: Self.ocean, fallbackStart: fallback)
    #expect(parsed == .dive(expected))
    #expect(expected.start == .instant(Date(timeIntervalSince1970: 1_793_016_109)))
    #expect(expected.fallbackStart == Date(timeIntervalSince1970: 1_793_016_109))
  }

  /// A refusal keeps the fingerprint's start, which names the original kept unread.
  @Test func aComputerTheLinkedLibraryDoesNotKnowIsRefused() throws {
    let unknown = DiveComputerIdentity(
      family: .suuntoNautic, vendor: "Suunto", product: "Ocean 2", serial: "253810000400",
      firmware: nil, familyNumber: 0, modelNumber: 1)
    let fallback = Date(timeIntervalSince1970: 1_793_016_109)
    let bytes = try fixture("suunto-ocean_253810000400_2026-10-26T1501", "bin")
    guard
      case .refused(let start, let reason) = LibDCDiveParser.parse(
        bytes, identity: unknown, fallbackStart: fallback)
    else {
      Issue.record("an unknown product read as a dive")
      return
    }
    #expect(start == .instant(fallback))
    #expect(reason.contains("Ocean 2"))
  }

  @Test func aNauticFingerprintIsItsStart() {
    #expect(
      LibDCDiveParser.fingerprintStart(Data([0x28, 0x7B, 0xDD, 0x6A]))
        == Date(timeIntervalSince1970: 0x6ADD_7B28))
    #expect(LibDCDiveParser.fingerprintStart(Data([1, 2])) == nil)
  }
}
