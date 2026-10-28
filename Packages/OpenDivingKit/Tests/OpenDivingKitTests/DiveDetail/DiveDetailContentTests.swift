import Foundation
import OpenDivingKit
import Testing

/// Each section's presence rule and contents over the fixtures, against the web's
/// `dive-detail-main.tsx` and `dive-detail-sidebar.tsx`.
struct DiveDetailContentTests {
  /// A fixture with some of its fields replaced, `null` written as `NSNull()`.
  private func dive(_ name: String, _ changes: [String: Any] = [:]) throws
    -> DiveReadWithMixtures
  {
    var object =
      try JSONSerialization.jsonObject(with: KitFixture.data(name)) as? [String: Any] ?? [:]
    object.merge(changes) { _, new in new }
    return try APICoding.decoder().decode(
      DiveReadWithMixtures.self, from: JSONSerialization.data(withJSONObject: object))
  }

  private func content(
    _ dive: DiveReadWithMixtures, trip: TripRead? = nil, course: CourseRead? = nil,
    contact: ContactRead? = nil, people: [UUID: PersonRead] = [:], units: UnitSystem = .metric
  ) -> DiveDetailContent {
    DiveDetailContent(
      dive: dive, trip: trip, course: course, contact: contact, people: people, units: units)
  }

  private func people() throws -> [UUID: PersonRead] {
    let page = try KitFixture.decode(PaginatedListResponse<PersonRead>.self, "people-page")
    return Dictionary(uniqueKeysWithValues: page.data.map { ($0.uuid, $0) })
  }

  // MARK: - Hero

  @Test func heroDropsTheAverageAtFourFigures() throws {
    let hero = content(try dive("dive-two-recordings")).hero
    #expect(hero.title == "#212 Blue Hole")
    #expect(
      hero.figures == [
        Figure(label: "Dive time", value: "54min"), Figure(label: "Max depth", value: "23 m"),
        Figure(label: "Water temp", value: "27°C"), Figure(label: "Visibility", value: "30 m"),
      ])
    #expect(hero.points.map(\.name) == ["Blue Hole"])
    #expect(hero.fixes.map(\.name) == ["Entry", "Exit"])
    #expect(hero.facts.last?.systemImage == "paperclip")
  }

  @Test func heroPutsTheAverageBeforeTheReadings() throws {
    let hero = content(try dive("dive-detail")).hero
    #expect(
      hero.figures.map(\.label) == ["Dive time", "Max depth", "Avg depth", "Water temp"])
    #expect(hero.figures[2].value == "14 m")
  }

  @Test func heroLeavesOutWhatTheDiveDoesNotRecord() throws {
    let hero = content(
      try dive(
        "dive-detail",
        ["max_depth": NSNull(), "avg_depth": NSNull(), "bottom_temperature": NSNull()])
    ).hero
    #expect(hero.figures.map(\.label) == ["Dive time"])
  }

  // MARK: - Profile

  @Test func profileOffersEachChartedRecordingPrimaryFirst() throws {
    let profile = try #require(content(try dive("dive-two-recordings")).profile)
    #expect(profile.cylinderLabels == [1, 2])
    #expect(
      profile.recordings.map(\.label) == [
        "Suunto Ocean · 000000000000 (My Computer)", "Shearwater Perdix 2",
      ])
    #expect(
      profile.recordings.map(\.description) == [
        "359 depth samples recorded by the dive computer, 1 marker.",
        "359 depth samples recorded by the dive computer, a heart rate peaking at 107 bpm and"
          + " averaging 77 bpm.",
      ])
  }

  @Test func profileIsAbsentWithoutAProfile() throws {
    #expect(content(try dive("dive-detail", ["recordings": []])).profile == nil)
  }

  @Test func profileDescriptionGroupsTheCountAndStatesTheCeiling() throws {
    var object =
      try JSONSerialization.jsonObject(with: KitFixture.data("dive-detail")) as? [String: Any]
      ?? [:]
    var recordings = object["recordings"] as? [[String: Any]] ?? []
    var profile = recordings[0]["profile"] as? [String: Any] ?? [:]
    profile["depth_sample_count"] = 3600
    profile["event_count"] = 2
    profile["max_ceiling"] = 3.24
    recordings[0]["profile"] = profile
    recordings[0]["device"] = NSNull()
    object["recordings"] = recordings
    let read = try APICoding.decoder().decode(
      DiveReadWithMixtures.self, from: JSONSerialization.data(withJSONObject: object))
    let charted = try #require(content(read).profile?.recordings.first)
    #expect(charted.label == "Dive computer · Recording 1")
    #expect(
      charted.description
        == "3,600 depth samples recorded by the dive computer, 2 markers, a deco ceiling to 3.2 m.")
  }

  /// `dive-profile-card.tsx`'s clause: either figure alone when only one is present, after the
  /// ceiling, and nothing when both are null.
  @Test func profileDescriptionStatesTheHeartRatesPeakAndAverage() throws {
    func description(max: Int?, average: Int?) throws -> String? {
      var object =
        try JSONSerialization.jsonObject(with: KitFixture.data("dive-detail")) as? [String: Any]
        ?? [:]
      var recordings = object["recordings"] as? [[String: Any]] ?? []
      var profile = recordings[0]["profile"] as? [String: Any] ?? [:]
      profile["event_count"] = 0
      profile["max_ceiling"] = 3.24
      profile["max_heart_rate"] = max ?? NSNull()
      profile["average_heart_rate"] = average ?? NSNull()
      recordings[0]["profile"] = profile
      object["recordings"] = recordings
      let read = try APICoding.decoder().decode(
        DiveReadWithMixtures.self, from: JSONSerialization.data(withJSONObject: object))
      return content(read).profile?.recordings.first?.description
    }
    let lead = "359 depth samples recorded by the dive computer, a deco ceiling to 3.2 m"
    #expect(
      try description(max: 107, average: 77)
        == lead + ", a heart rate peaking at 107 bpm and averaging 77 bpm.")
    #expect(try description(max: 107, average: nil) == lead + ", a heart rate peaking at 107 bpm.")
    #expect(try description(max: nil, average: 77) == lead + ", a heart rate averaging 77 bpm.")
    #expect(try description(max: nil, average: nil) == lead + ".")
  }

  // MARK: - Tanks and gas

  @Test func tanksAreOneCardPerCylinder() throws {
    let tanks = try #require(content(try dive("dive-two-recordings")).tanks)
    #expect(tanks.tanks.map(\.number) == ["#1", "#2"])
    // Helium unrecorded: no name and no MOD, as the web's `gasName` and `isNameableMix`.
    #expect(tanks.tanks.map(\.gas) == [nil, nil])
    #expect(tanks.tanks.map(\.role) == ["Bottom", "Deco"])
    #expect(tanks.tanks[0].facts == ["Faber Twinset", "12 L", "O₂ 32%"])
    #expect(tanks.tanks[1].facts == ["7 L", "O₂ 50%", "Staged"])
    #expect(tanks.tanks[0].start == "200 bar")
    #expect(tanks.tanks[0].end == "60 bar")
    #expect(tanks.tanks.map(\.modCondition) == [nil, nil])
    #expect(tanks.tanks.map(\.mod) == [nil, nil])
    #expect(tanks.warning == nil)
    #expect(tanks.tanks.allSatisfy { !$0.warned })
  }

  @Test func aModPrintsComparablyAndFloored() throws {
    let metric = try #require(content(try dive("dive-detail")).tanks?.tanks.first)
    #expect(metric.gas == "EAN31")
    #expect(metric.facts == ["O₂ 31%"])
    #expect(metric.modCondition == "@ 1.4")
    #expect(metric.mod == "35.16 m")
    let imperial = try #require(content(try dive("dive-detail"), units: .imperial).tanks)
    #expect(imperial.tanks[0].mod == "115.3 ft")
    #expect(imperial.tanks[0].start == "1886 psi")
  }

  @Test func aSingleCylinderPastItsModIsWarnedAndMarked() throws {
    let tanks = try #require(
      content(try dive("dive-detail", ["max_depth": 40.0])).tanks)
    #expect(tanks.warning != nil)
    #expect(tanks.tanks[0].warned)
  }

  @Test func heliumShowsOnEveryCardOnceAnyCylinderHasSome() throws {
    var object =
      try JSONSerialization.jsonObject(with: KitFixture.data("dive-two-recordings"))
      as? [String: Any] ?? [:]
    var mixtures = object["mixtures"] as? [[String: Any]] ?? []
    mixtures[0]["helium"] = 0.0
    mixtures[1]["helium"] = 35.0
    object["mixtures"] = mixtures
    let read = try APICoding.decoder().decode(
      DiveReadWithMixtures.self, from: JSONSerialization.data(withJSONObject: object))
    let tanks = try #require(content(read).tanks)
    #expect(tanks.tanks[0].facts.contains("He 0%"))
    #expect(tanks.tanks[1].facts.contains("He 35%"))
    #expect(tanks.tanks[1].gas == "50/35")
  }

  @Test func noMixturesMeansNoTanksAndNoGasCard() throws {
    let page = content(try dive("dive-detail", ["mixtures": []]))
    #expect(page.tanks == nil)
    #expect(page.gasConsumption == nil)
  }

  @Test func aMixtureWithoutGasUseSaysSo() throws {
    #expect(
      content(try dive("dive-detail")).gasConsumption
        == .unavailable(DiveDetailContent.gasUseUnavailable))
  }

  @Test func attributedGasUseIsATable() throws {
    let gas = content(try dive("dive-two-recordings")).gasConsumption
    guard case .table(let rows, let total, _, let coverage) = gas else {
      Issue.record("expected a table, got \(String(describing: gas))")
      return
    }
    #expect(rows.map(\.label) == ["1", "2"])
    #expect(rows[0].cells == ["39min", "24.8 m", "1680 L", "14 L/min", "1.19 bar/min"])
    #expect(rows[1].cells == nil)
    #expect(rows[1].emptyText == "No figures")
    #expect(total == nil)
    #expect(
      coverage
        == "These figures cover 39min of the 48min the dive computer recorded - the rest "
        + "couldn't be assigned to a cylinder.")
  }

  @Test func aTotalRowOnceTwoCylindersAreAttributed() throws {
    let gasUse: [String: Any] = [
      "gas_used": 2000.0, "rmv": 14.29, "sac_bar_per_min": NSNull(),
      "tanks": [
        [
          "gas_number": 1, "gas_used": 1680.0, "rmv": 14.0, "sac_bar_per_min": 1.19,
          "seconds_on_gas": 2355, "mean_depth": 24.8,
        ],
        [
          "gas_number": 2, "gas_used": 320.0, "rmv": 15.0, "sac_bar_per_min": 2.5,
          "seconds_on_gas": 20, "mean_depth": 6.0,
        ],
      ],
      "attributed_seconds": 2375, "duration": 2400,
    ]
    let gas = content(try dive("dive-two-recordings", ["gas_use": gasUse])).gasConsumption
    guard case .table(let rows, let total, _, let coverage) = gas else {
      Issue.record("expected a table")
      return
    }
    #expect(rows[1].cells?.first == "<1min")
    #expect(total?.label == "Total")
    #expect(total?.cells == ["40min", "-", "2000 L", "14.29 L/min", "-"])
    #expect(coverage == nil)
  }

  @Test func wholeDiveGasUseIsThreeFigures() throws {
    let gasUse: [String: Any] = [
      "gas_used": 1800.0, "rmv": 14.29, "sac_bar_per_min": NSNull(), "tanks": [],
      "attributed_seconds": NSNull(), "duration": NSNull(),
    ]
    let gas = content(try dive("dive-detail", ["gas_use": gasUse])).gasConsumption
    #expect(
      gas
        == .figures(
          [
            Figure(label: "RMV", value: "14.29 L/min"), Figure(label: "SAC", value: nil),
            Figure(label: "Gas used", value: "1800 L"),
          ],
          note: "What you'd have breathed doing the same dive at the surface, from an average "
            + "depth of 13.62 m. Assumes salt water at sea level. Lower is better."))
  }

  // MARK: - Exposure, gear, species, notes

  @Test func exposureIsThePrimaryRecordingsAlone() throws {
    let exposure = try #require(content(try dive("dive-two-recordings")).exposure)
    #expect(exposure.readings.map(\.label) == ["CNS", "OTU"])
    #expect(exposure.readings.map(\.start) == ["—", "—"])
    #expect(exposure.readings.map(\.end) == ["14%", "37"])
    #expect(exposure.readings.allSatisfy { $0.alert == nil })
    #expect(exposure.surfacePressure == nil)
  }

  @Test func exposureEmphasisesACnsEndAtTheLimit() throws {
    var object =
      try JSONSerialization.jsonObject(with: KitFixture.data("dive-detail")) as? [String: Any]
      ?? [:]
    var recordings = object["recordings"] as? [[String: Any]] ?? []
    recordings[0]["cns_end"] = 100.0
    recordings[0]["otu_end"] = NSNull()
    recordings[0]["surface_pressure_bar"] = 1.013
    object["recordings"] = recordings
    let read = try APICoding.decoder().decode(
      DiveReadWithMixtures.self, from: JSONSerialization.data(withJSONObject: object))
    let exposure = try #require(content(read).exposure)
    #expect(exposure.readings.map(\.label) == ["CNS"])
    #expect(exposure.readings[0].alert == "over the 100% single-dive limit")
    #expect(exposure.surfacePressure == "1.013 bar")
  }

  @Test func exposureIsAbsentWithoutReadouts() throws {
    #expect(content(try dive("dive-detail", ["recordings": []])).exposure == nil)
  }

  @Test func gearListsItemsAndTheWeight() throws {
    let gear = try #require(content(try dive("dive-two-recordings")).gear)
    #expect(gear.items.map(\.type) == ["Cylinder"])
    #expect(gear.items.map(\.brand) == ["Faber"])
    #expect(gear.items.map(\.name) == ["Twinset"])
    #expect(gear.items.allSatisfy { !$0.rented && !$0.archived })
    #expect(gear.weight == "6 kg")
    #expect(content(try dive("dive-detail")).gear == nil)
    #expect(content(try dive("dive-detail", ["weight": 4.0])).gear?.items == [])
  }

  @Test func sightingsCarryACountOrABand() throws {
    let sightings = content(try dive("dive-two-recordings")).sightings
    #expect(sightings.map(\.photoVersion) == ["ab12", nil])
    #expect(sightings[0].card.commonName == "Twoband anemonefish")
    #expect(sightings[0].card.scientificName == "Amphiprion bicinctus")
    #expect(sightings[0].card.figures == [Figure(label: "Count", value: "3")])
    #expect(sightings[1].card.commonName == "Muraenidae")
    #expect(sightings[1].card.scientificName == "Muraenidae (Family)")
    #expect(sightings[1].card.figures == [Figure(label: "Abundance", value: "Teeming")])
    #expect(sightings[1].card.note == "By the arch")
  }

  @Test func aKnownBandShowsItsRangeAndSeenNotCountedNoFigure() throws {
    var object =
      try JSONSerialization.jsonObject(with: KitFixture.data("dive-two-recordings"))
      as? [String: Any] ?? [:]
    var sightings = object["sightings"] as? [[String: Any]] ?? []
    sightings[0]["count"] = NSNull()
    sightings[1]["abundance"] = "many"
    object["sightings"] = sightings
    let read = try APICoding.decoder().decode(
      DiveReadWithMixtures.self, from: JSONSerialization.data(withJSONObject: object))
    let cards = content(read).sightings.map(\.card)
    #expect(cards[0].figures.isEmpty)
    #expect(cards[1].figures == [Figure(label: "Abundance", value: "Many 11–100")])
  }

  @Test func notesOnlyWhenWritten() throws {
    #expect(content(try dive("dive-two-recordings")).notes == "Two computers, two tanks.")
    #expect(content(try dive("dive-detail")).notes == nil)
  }

  // MARK: - Sidebar

  @Test func trainingIsTheCoursesName() throws {
    let course = try KitFixture.decode(CourseRead.self, "course")
    #expect(content(try dive("dive-detail"), course: course).course == "Solo Diver")
    #expect(content(try dive("dive-detail")).course == nil)
  }

  @Test func locationNamesEverythingTheDiveRecordsOfWhereItWas() throws {
    let trip = try KitFixture.decode(TripRead.self, "trip")
    let contact = try KitFixture.decode(ContactRead.self, "contact")
    let location = try #require(
      content(try dive("dive-two-recordings"), trip: trip, contact: contact).location)
    #expect(location.trip?.name == "Dahab 2026 (September)")
    #expect(location.trip?.locations == "Dahab, Egypt")
    #expect(location.diveCenter?.name == "Big Blue Tech")
    #expect(location.diveCenter?.place == "Koh Tao, Thailand")
    #expect(location.diveCenter?.phone == nil)
    #expect(location.sitesLabel == "Dive site")
    #expect(location.sites.map(\.name) == ["Blue Hole"])
    #expect(location.sites.map(\.location) == ["Dahab, South Sinai, Egypt"])
    #expect(location.entry == "28.420546, 34.457623")
    #expect(location.exit == "28.420563, 34.457658")
    #expect(location.drift == "4 m")
    #expect(location.entryType == "Boat")
    #expect(location.boatName == "Legend")
  }

  @Test func locationRendersForAFixAlone() throws {
    let location = try #require(content(try dive("dive-detail")).location)
    #expect(location.trip == nil && location.sites.isEmpty)
    #expect(location.entry != nil)
  }

  @Test func locationIsAbsentWithNothingToPlaceTheDive() throws {
    let page = content(
      try dive(
        "dive-detail",
        [
          "entry_latitude": NSNull(), "entry_longitude": NSNull(), "exit_latitude": NSNull(),
          "exit_longitude": NSNull(),
        ]))
    #expect(page.location == nil)
  }

  @Test func peopleAreNamedThroughThePeopleTable() throws {
    let rows = content(try dive("dive-two-recordings"), people: try people()).people
    #expect(rows.first == PersonRowContent(name: "Ana Diaz", username: "ana", role: "Buddy"))
    #expect(content(try dive("dive-two-recordings")).people.isEmpty)
  }

  @Test func environmentInTheWebsOrder() throws {
    #expect(
      content(try dive("dive-two-recordings")).environment == [
        Figure(label: "Air temperature", value: "24°C"),
        Figure(label: "Water type", value: "Lake"),
        Figure(label: "Altitude", value: "372 m"),
        Figure(label: "Current", value: "Light"),
        Figure(label: "Waves", value: "Calm"),
        Figure(label: "Weather", value: "Clear"),
      ])
    #expect(content(try dive("dive-detail")).environment.isEmpty)
  }

  @Test func recordingsDescribeEachComputer() throws {
    let recordings = content(try dive("dive-two-recordings")).recordings
    #expect(recordings.count == 2)
    #expect(recordings[0].device == "Suunto Ocean · 000000000000 (My Computer)")
    #expect(recordings[0].name == "Recording 1 · shown by default")
    #expect(recordings[0].settings == "GF 50/85")
    #expect(recordings[0].readouts == "CNS — → 14% · OTU — → 37")
    #expect(recordings[0].started == nil)
    #expect(recordings[0].firmware == "Firmware 2.51.28")
    #expect(recordings[0].noFileKept == nil)
    #expect(recordings[0].files.map(\.detail) == ["Suunto app JSON · 1.2 MB", "FIT · 26 KB"])
    #expect(recordings[1].name == "Recording 2")
    #expect(
      recordings[1].settings
        == "Closed circuit · ZHL-16C GF 30/70 · conservatism -1 · salinity EN13319")
    #expect(recordings[1].started == "Started 10:05")
    #expect(recordings[1].firmware == nil)
    #expect(
      recordings[1].noFileKept
        == "No file kept — these samples were imported through the converter.")
  }

  @Test func aLoneRecordingIsNotNumbered() throws {
    #expect(content(try dive("dive-detail")).recordings.map(\.name) == [nil])
  }
}
