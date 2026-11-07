import Foundation
import OpenDivingKit
import Testing

/// Each entry of a modified dive's `changes`, in the web's words.
struct ImportChangeRowTests {
  private func row(
    _ member: String, _ before: String, _ after: String, units: UnitSystem = .metric
  ) throws -> ImportChangeRow {
    let json = #"{"member":"\#(member)","before":\#(before),"after":\#(after)}"#
    let change = try APICoding.decoder().decode(LogbookImportChange.self, from: Data(json.utf8))
    return ImportChangeRow.row(change, units: units)
  }

  @Test func theFixturesEntriesEachReadAsALine() throws {
    let read = try KitFixture.decode(LogbookImportRead.self, "import-modified")
    let dive = try #require(read.dives.first)
    let rows = dive.changes.map { ImportChangeRow.row($0, units: .metric) }
    #expect(rows.count == dive.changes.count)
    #expect(rows.contains(.value(label: "Entry latitude", before: "—", after: "28.496525")))
    #expect(rows.contains(.value(label: "Recording 1: Device name", before: "—", after: "Ocean")))
    #expect(rows.contains(.element("File added — dive-0214.json")))
    #expect(rows.contains(.element("Recording 1: Curve added — Tank pressure")))
  }

  @Test func aValueReadsInTheDiversUnits() throws {
    #expect(
      try row("max_depth", "30", "31", units: .imperial)
        == .value(label: "Maximum depth", before: "98 ft", after: "102 ft"))
    #expect(
      try row("mixtures/1/start_pressure", "null", "200")
        == .value(label: "Tank 2: Start pressure", before: "—", after: "200 bar"))
    #expect(
      try row("submerged_time", "2700", "3000")
        == .value(label: "Dive time", before: "45min", after: "50min"))
    #expect(
      try row("water_type", #""salt""#, #""fresh""#)
        == .value(label: "Water type", before: "Salt water", after: "Fresh water"))
    #expect(
      try row("trip_uuid", "null", #""01a0""#)
        == .value(label: "Trip", before: "—", after: "Linked"))
  }

  @Test func aNestedMemberNamesItsOwner() throws {
    #expect(
      try row("recordings/1/deco_model/gf_high", "80", "85")
        == .value(label: "Recording 2: Decompression model GF high", before: "80%", after: "85%"))
    #expect(
      try row("recordings/0/profile/duration", "3473000", "3600000")
        == .value(label: "Recording 1: Profile span", before: "58min", after: "1h"))
  }

  @Test func anElementIsOneLine() throws {
    #expect(try row("tags/2", "null", #""drift""#) == .element("Tag added — drift"))
    #expect(try row("tags/2", #""drift""#, "null") == .element("Tag removed — drift"))
    #expect(try row("people/0", "null", #"{"person_uuid":"01a0"}"#) == .element("Person added"))
    #expect(
      try row("mixtures/1", "null", #"{"oxygen":32,"helium":0,"volume":12}"#)
        == .element("Tank 2 added — EAN32, 12 L"))
    #expect(
      try row(
        "recordings/1", "null",
        #"{"device":{"brand":"Suunto","model":"Ocean"},"files":[{"original_filename":"a.fit"}]}"#)
        == .element("Recording 2 added — Suunto Ocean, a.fit"))
  }

  @Test func aListPositionHoldingAnotherValueIsAValue() throws {
    #expect(
      try row("tags/0", #""reef""#, #""wall""#)
        == .value(label: "Tag", before: "reef", after: "wall"))
  }

  @Test func aTanksGasNumberReadsAsTheTankRowsDo() throws {
    #expect(
      try row("mixtures/0/gas_number", "null", "0")
        == .value(label: "Tank 1: Gas number", before: "—", after: "0"))
  }

  @Test func aCurveReadsByTheNameTheChartGivesIt() throws {
    for channel in ProfileChannel.allCases {
      #expect(
        try row("recordings/0/profile/channels/2", "null", #""\#(channel.rawValue)""#)
          == .element("Recording 1: Curve added — \(channel.label)"))
    }
    #expect(
      try row("recordings/1/profile/channels/0", #""ndl""#, "null")
        == .element("Recording 2: Curve removed — No-deco time"))
    #expect(
      try row("recordings/0/profile/channels/1", #""ceiling""#, #""heart_rate""#)
        == .value(label: "Recording 1: Curve", before: "Deco ceiling", after: "Heart rate"))
  }

  @Test func aCurveTheChartDoesNotKnowKeepsItsWriterName() throws {
    #expect(
      try row("recordings/0/profile/channels/2", "null", #""co2""#)
        == .element("Recording 1: Curve added — co2"))
  }

  @Test func whatHasNoLabelReadsByItsPath() throws {
    #expect(
      try row("mixtures/0/regulator", "null", "0")
        == .value(label: "mixtures/0/regulator", before: "—", after: "0"))
    #expect(
      try row("gas_use", #"{"rmv":14.5,"a":true}"#, "null")
        == .value(label: "gas_use", before: #"{"a":true,"rmv":14.5}"#, after: "—"))
  }

  @Test func aValueOfAnotherTypeIsShownAsSent() throws {
    #expect(
      try row("max_depth", #""deep""#, "true")
        == .value(label: "Maximum depth", before: "deep", after: "true"))
  }
}
