import OpenDivingKit
import Testing

/// Golden rows from the web's own tests: `src/lib/format.test.ts`, `src/lib/dive-gas.test.ts`
/// (`gasAttributionNote`) and `src/lib/contact.test.ts`.
struct DiveDetailTextTests {
  static let fileSizes: [(Int, String)] = [
    (1, "1 KB"), (400, "1 KB"), (1024, "1 KB"), (512_000, "500 KB"), (1_048_576, "1.0 MB"),
    (2_621_440, "2.5 MB"), (5_242_880, "5.0 MB"), (1_073_741_824, "1.0 GB"), (2560, "3 KB"),
    (1_310_720, "1.3 MB"), (0, "0 KB"), (-1, "0 KB"),
  ]

  @Test(arguments: fileSizes)
  func fileSize(bytes: Int, expected: String) {
    #expect(DiveDetailText.fileSize(bytes) == expected)
  }

  @Test func fileSizeSwitchesUnitAtTheBoundary() {
    #expect(DiveDetailText.fileSize(1024 * 1024 - 1).hasSuffix("KB"))
    #expect(DiveDetailText.fileSize(1024 * 1024 * 1024 - 1).hasSuffix("MB"))
  }

  @Test func countNoun() {
    #expect(DiveDetailText.countNoun(1, "marker") == "1 marker")
    #expect(DiveDetailText.countNoun(0, "marker") == "0 markers")
    #expect(DiveDetailText.countNoun(3, "address", plural: "addresses") == "3 addresses")
  }

  @Test func gearItemLabel() {
    #expect(
      DiveDetailText.gearItemLabel(name: "MK25 EVO", brand: "Scubapro") == "Scubapro MK25 EVO")
    #expect(DiveDetailText.gearItemLabel(name: "Wing 17L", brand: nil) == "Wing 17L")
    #expect(DiveDetailText.gearItemLabel(name: "Wing 17L", brand: "") == "Wing 17L")
  }

  @Test func noFileKeptSentenceNamesWhereTheSamplesCameFrom() {
    #expect(DiveDetailText.noFileKeptSentence(fileCount: 1, provenance: "merge") == nil)
    #expect(
      DiveDetailText.noFileKeptSentence(fileCount: 0, provenance: "divejson_import")
        == "No file kept — these samples were imported through the converter.")
    #expect(
      DiveDetailText.noFileKeptSentence(fileCount: 0, provenance: "merge")
        == "No file kept — these samples were merged from two recordings.")
    #expect(
      DiveDetailText.noFileKeptSentence(fileCount: 0, provenance: nil)
        == "No file kept — nothing was stored here to re-read this recording from.")
  }

  @Test func contactAddressDropsEmptyParts() {
    #expect(DiveDetailText.contactAddress(["Koh Tao", nil, "Thailand"]) == "Koh Tao, Thailand")
    #expect(DiveDetailText.contactAddress([" ", nil, ""]) == nil)
  }

  static let websites: [(String, String)] = [
    ("https://blueocean.example/", "blueocean.example"),
    ("http://blueocean.example/dahab?lang=en", "blueocean.example/dahab?lang=en"),
    ("blueocean", "blueocean"),
    ("https://example.com/dahab/", "example.com/dahab/"),
    ("https://Example.com:8443/a?b=c", "example.com:8443/a?b=c"),
    ("not a url", "not a url"),
  ]

  @Test(arguments: websites)
  func website(stored: String, expected: String) {
    #expect(DiveDetailText.website(stored) == expected)
  }

  @Test func dialableKeepsDigitsAndPlus() {
    #expect(DiveDetailText.dialable("+20 (69) 364-0000") == "+20693640000")
  }

  @Test func timeOnGasSaysUnderAMinute() {
    #expect(DiveDetailText.timeOnGas(seconds: 20) == "<1min")
    #expect(DiveDetailText.timeOnGas(seconds: 30) == "1min")
    #expect(DiveDetailText.timeOnGas(seconds: 2355) == "39min")
  }

  @Test func gasAttributionNote() {
    #expect(DiveDetailText.gasAttributionNote(attributedSeconds: 2700, duration: 2700) == nil)
    #expect(DiveDetailText.gasAttributionNote(attributedSeconds: 2655, duration: 2700) == nil)
    #expect(
      DiveDetailText.gasAttributionNote(attributedSeconds: 2280, duration: 2520)
        == "These figures cover 38min of the 42min the dive computer recorded - the rest "
        + "couldn't be assigned to a cylinder.")
    #expect(
      DiveDetailText.gasAttributionNote(attributedSeconds: 2075, duration: 4300)?.contains(
        "35min of the 1h 12min the dive computer recorded") == true)
    #expect(DiveDetailText.gasAttributionNote(attributedSeconds: nil, duration: 2700) == nil)
    #expect(DiveDetailText.gasAttributionNote(attributedSeconds: 3000, duration: 2700) == nil)
    #expect(DiveDetailText.gasAttributionNote(attributedSeconds: 0, duration: 0) == nil)
  }

  @Test func neighborLabelCarriesTheNumberAndTheDay() throws {
    let start = try #require(DiveTimestamp(wireValue: "2026-10-02T11:36:20.930000+03:00"))
    #expect(
      DiveDetailText.neighborLabel("Previous dive", number: 531, start: start)
        == "Previous dive: #531, Oct 2, 2026")
  }
}
