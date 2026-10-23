import OpenDivingKit
import Testing

/// Every table against the web's own at `opendiving-web` `ec014ff9` — `src/lib/api/dives.ts`,
/// `dive-mixtures.ts`, `people.ts`, `gear.ts`, `logbook-import.ts`, `certifications.ts` —
/// and against a value it lacks.
struct VocabularyLabelsTests {
  private typealias Labels = VocabularyLabels

  /// `labels.ts:8-18`.
  @Test func fallbackDeSnakesAndCapitalises() {
    #expect(Labels.labelOrFallback([:], "semi_closed") == "Semi closed")
    #expect(Labels.labelOrFallback([:], "x") == "X")
    #expect(Labels.labelOrFallback([:], "") == "")
    #expect(Labels.labelOrFallback(["a": "Alpha"], "a") == "Alpha")
  }

  @Test func waterAndDiveTypes() {
    #expect(
      ["salt", "fresh", "brackish"].map(Labels.waterType) == [
        "Salt water", "Fresh water", "Brackish",
      ])
    #expect(
      ["open_circuit", "closed_circuit", "semi_closed", "freedive", "snorkel", "surface_supplied"]
        .map(Labels.diveType) == [
          "Open circuit", "Closed circuit", "Semi-closed circuit", "Freediving", "Snorkeling",
          "Surface-supplied",
        ])
    #expect(Labels.waterType("lake_water") == "Lake water")
    #expect(Labels.diveType("sidemount") == "Sidemount")
  }

  /// `dives.ts:63` and `:104`: no chip for salt water, open circuit or an unknown value.
  @Test func chipAbbreviationsHaveNoFallback() {
    #expect(Labels.waterTypeAbbreviation("salt") == nil)
    #expect(Labels.waterTypeAbbreviation("fresh") == "Fresh")
    #expect(Labels.waterTypeAbbreviation("brackish") == "Brackish")
    #expect(Labels.waterTypeAbbreviation("lake") == nil)
    #expect(Labels.diveTypeAbbreviation("open_circuit") == nil)
    #expect(
      ["closed_circuit", "semi_closed", "surface_supplied", "freedive", "snorkel"].map(
        Labels.diveTypeAbbreviation) == ["CCR", "SCR", "SSD", "Freedive", "Snorkel"])
    #expect(Labels.diveTypeAbbreviation("sidemount") == nil)
  }

  @Test func conditionsAndEntry() {
    #expect(
      ["none", "light", "moderate", "strong", "extreme"].map(Labels.current) == [
        "None", "Light", "Moderate", "Strong", "Extreme",
      ])
    #expect(
      ["calm", "slight", "moderate", "rough"].map(Labels.waves) == [
        "Calm", "Slight", "Moderate", "Rough",
      ])
    #expect(
      ["clear", "partly_cloudy", "overcast", "rain", "storm", "snow", "fog"].map(Labels.weather)
        == [
          "Clear", "Partly cloudy", "Overcast", "Rain", "Storm", "Snow", "Fog",
        ])
    #expect(
      ["shore", "boat", "pier", "pool"].map(Labels.entryType) == ["Shore", "Boat", "Pier", "Pool"])
    #expect(Labels.current("ripping_tide") == "Ripping tide")
    #expect(Labels.waves("big") == "Big")
    #expect(Labels.weather("hail_storm") == "Hail storm")
    #expect(Labels.entryType("cave_entry") == "Cave entry")
  }

  @Test func cylinders() {
    #expect(
      ["bottom", "deco", "diluent", "oxygen"].map(Labels.gasRole) == [
        "Bottom", "Deco", "Diluent", "Oxygen",
      ])
    #expect(["parallel", "staged"].map(Labels.tankUsage) == ["Parallel", "Staged"])
    #expect(Labels.gasRole("bail_out") == "Bail out")
    #expect(Labels.tankUsage("side_slung") == "Side slung")
  }

  @Test func personRoles() {
    #expect(
      ["buddy", "guide", "instructor", "student", "companion"].map(Labels.personRole) == [
        "Buddy", "Guide", "Instructor", "Student", "Companion",
      ])
    #expect(Labels.personRole("boat_captain") == "Boat captain")
  }

  /// `gear.ts:56-86`, with the five rows the census sha predates.
  @Test func gearTypes() {
    let keys = [
      "mask", "snorkel", "fins", "wetsuit", "drysuit", "vest", "hood", "gloves", "boots", "bcd",
      "backplate", "wing", "regulator", "rebreather", "computer", "transmitter", "cylinder",
      "light", "scooter", "smb", "mirror", "whistle", "reel", "knife", "line_cutter", "shears",
      "compass", "camera", "other",
    ]
    #expect(
      keys.map { Labels.gearType($0) } == [
        "Mask", "Snorkel", "Fins", "Wetsuit", "Drysuit", "Vest", "Hood", "Gloves", "Boots", "BCD",
        "Backplate", "Wing", "Regulator", "Rebreather", "Dive computer", "Transmitter", "Cylinder",
        "Light", "Scooter", "SMB", "Mirror", "Whistle", "Reel", "Knife", "Line cutter", "Shears",
        "Compass", "Camera", "Other",
      ])
    #expect(Labels.gearType("dry_bag") == "Dry bag")
    #expect(Labels.gearType(nil) == nil)
    #expect(Labels.gearType("") == nil)
  }

  /// `dives.ts:399-414`.
  @Test func abundance() {
    #expect(["few", "many", "abundant"].map(Labels.abundance) == ["Few", "Many", "Abundant"])
    #expect(["few", "many", "abundant"].map(Labels.abundanceRange) == ["2–10", "11–100", "101+"])
    #expect(Labels.abundance("swarming") == "Swarming")
    #expect(Labels.abundanceRange("swarming") == nil)
  }

  /// `logbook-import.ts:58-99`.
  @Test func importSources() {
    #expect(
      ["uddf", "ssrf", "fit", "suunto_json", "suunto_xml", "divejson", "archive", "zip"].map(
        Labels.importSource) == [
          "UDDF", "Subsurface", "FIT", "Suunto app JSON", "Suunto DM5 XML", "DiveJSON",
          "OpenDiving archive", "Zip",
        ])
    #expect(Labels.importSource("shearwater_db") == "Shearwater db")
  }

  /// `certifications.ts:89-176`.
  @Test func certifications() {
    #expect(Labels.certificationAgency("padi") == "PADI")
    #expect(Labels.certificationAgency("scotsac") == "ScotSAC")
    #expect(Labels.certificationAgency("nss_cds") == "NSS-CDS")
    #expect(Labels.certificationAgency("apnea_academy") == "Apnea Academy")
    #expect(Labels.certificationAgency("other") == "Other")
    #expect(Labels.certificationAgency("other", other: "  Local Club ") == "Local Club")
    #expect(Labels.certificationAgency("other", other: "   ") == "Other")
    #expect(Labels.certificationAgency("new_agency") == "New agency")
    #expect(Labels.certificationAgency(nil) == nil)
    #expect(Labels.certificationSide("front") == "Front")
    #expect(Labels.certificationSide("back") == "Back")
    #expect(Labels.certificationSide("edge") == nil)
  }
}
