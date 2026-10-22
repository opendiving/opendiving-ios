import OpenDivingKit
import Testing

/// Transcribed from `src/components/dives/dive-card.render.test.tsx` and
/// `dive-title.render.test.tsx` at `opendiving-web` `ec014ff9`, over the same fixture: dive
/// #212 at `2026-04-04T10:04:47+02:00`, 2700 s in the water, 30.52 m deep, 18.2 m on
/// average, 24.4 °C.
struct DiveCardContentTests {
  private func card(
    siteNames: [String] = [],
    isCourse: Bool = false,
    rating: Int? = nil,
    waterType: String? = nil,
    diveType: String? = nil,
    tags: [String] = [],
    locationName: String? = nil,
    boatName: String? = nil,
    hasRecording: Bool = false,
    maxDepth: Double? = 30.52,
    avgDepth: Double? = 18.2,
    waterTemperature: Double? = 24.4,
    outline: [Int] = [],
    units: UnitSystem = .metric
  ) -> DiveCardContent {
    .dive(
      number: 212, siteNames: siteNames, isCourse: isCourse, rating: rating, waterType: waterType,
      diveType: diveType, tags: tags, start: DiveTimestamp(wireValue: "2026-04-04T10:04:47+02:00")!,
      locationName: locationName, boatName: boatName, hasRecording: hasRecording,
      submergedSeconds: 2700, maxDepth: maxDepth, avgDepth: avgDepth,
      waterTemperature: waterTemperature, outline: outline, units: units)
  }

  private func figures(_ content: DiveCardContent) -> [[String?]] {
    content.figures.map { [$0.label, $0.value] }
  }

  /// `dive-card.render.test.tsx:203`.
  @Test func titlesItsFigures() {
    #expect(
      figures(card()) == [["Dive time", "45min"], ["Max depth", "31 m"], ["Water temp", "24°C"]])
  }

  /// `:211`.
  @Test func averageDepthInPlaceOfAMissingTemperature() {
    #expect(
      figures(card(waterTemperature: nil))
        == [["Dive time", "45min"], ["Max depth", "31 m"], ["Avg depth", "18 m"]])
  }

  /// `:221` — the web prints `-`; a nil value is drawn as the same muted dash.
  @Test func twoFiguresWithNothingElseRecorded() {
    #expect(
      figures(card(maxDepth: nil, avgDepth: nil, waterTemperature: nil))
        == [["Dive time", "45min"], ["Max depth", nil]])
  }

  /// `:236`, `:248`.
  @Test func zeroIsAReading() {
    #expect(
      figures(card(maxDepth: 0, avgDepth: 0, waterTemperature: nil))
        == [["Dive time", "45min"], ["Max depth", "0 m"], ["Avg depth", "0 m"]])
    #expect(figures(card(waterTemperature: 0))[2] == ["Water temp", "0°C"])
  }

  @Test func figuresInImperial() {
    #expect(
      figures(card(units: .imperial))
        == [["Dive time", "45min"], ["Max depth", "100 ft"], ["Water temp", "76°F"]])
  }

  /// `:254`; `dive-title.render.test.tsx:77-87`.
  @Test func titleAndFacts() {
    let content = card(siteNames: ["Blue Hole"], locationName: "Dahab, Egypt")
    #expect(content.title == "#212 Blue Hole")
    #expect(content.facts.map(\.text) == ["Apr 4, 2026, 10:04", "Dahab, Egypt"])
    #expect(
      card(siteNames: ["Pescador Island", "Panagsama Wall"]).title == "#212 Pescador Island +1")
    #expect(card().title == "Dive #212")
  }

  /// `:274`.
  @Test func courseChipsAndBoat() {
    let content = card(
      isCourse: true, waterType: "fresh", diveType: "closed_circuit", boatName: "Legend")
    #expect(content.isCourse)
    #expect(
      content.chips == [
        Chip(text: "Fresh", accessibilityLabel: "Fresh water", kind: .vocabulary),
        Chip(text: "CCR", accessibilityLabel: "Closed circuit", kind: .vocabulary),
      ])
    #expect(
      content.facts.last == Fact(text: "Legend", systemImage: "ferry", accessibilityLabel: "Boat"))
  }

  /// `:290`.
  @Test func tagsFollowTheKindAndTheRatingIsKept() {
    let content = card(rating: 4, diveType: "closed_circuit", tags: ["night", "Wreck"])
    #expect(content.chips.map(\.text) == ["CCR", "night", "Wreck"])
    #expect(content.chips.map(\.kind) == [.vocabulary, .tag, .tag])
    #expect(content.rating == 4)
  }

  /// `dive-chips.tsx:80-87`: salt water and open circuit go without saying.
  @Test func saltWaterOpenCircuitHasNoVocabularyChip() {
    #expect(card(waterType: "salt", diveType: "open_circuit").chips.isEmpty)
    #expect(card(waterType: "lake", diveType: "sidemount").chips.isEmpty)
  }

  /// `:306`, `:312`.
  @Test func paperclipWhereARecordingIsAttached() {
    #expect(
      card(hasRecording: true).facts.last
        == Fact(systemImage: "paperclip", accessibilityLabel: "Recording attached"))
    #expect(card(hasRecording: false).facts.count == 1)
  }

  /// `:179`, `:191`; `dive-profile-silhouette.tsx`: each depth over the deepest.
  @Test func outline() {
    #expect(card(outline: [300, 3052, 500]).outline == [300.0 / 3052, 1, 500.0 / 3052])
    #expect(card(outline: []).outline.isEmpty)
    #expect(card(outline: [0, 0]).outline.isEmpty)
  }

  /// `dive-sites-label.tsx`: `-` with no site.
  @Test func sitesLabel() {
    #expect(DiveTitles.sitesLabel([]) == "-")
    #expect(
      DiveTitles.sitesLabel(["Pescador Island", "Panagsama Wall", "Kasai"]) == "Pescador Island +2")
  }
}
