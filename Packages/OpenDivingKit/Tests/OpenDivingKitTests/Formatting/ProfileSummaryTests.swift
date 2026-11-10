import Foundation
import OpenDivingKit
import Testing

/// The profile's head over the `dive-stats` fixture, as `app/home/page.render.test.tsx` at
/// `opendiving-web` `c8f5fd32` has the Home hero print it.
struct ProfileSummaryTests {
  static func stats(_ changes: [String: Any] = [:]) throws -> UserDiveStatsRead {
    var object = try #require(
      JSONSerialization.jsonObject(with: KitFixture.data("dive-stats")) as? [String: Any])
    object.merge(
      [
        "total_dives": 212, "max_depth": 38.6, "total_submerged_time": 561_600,
        "species_seen": 17, "dive_site_count": 48, "first_dive_on": "2014-12-20",
        "last_dive_on": "2026-10-05",
      ]
    ) { _, new in new }
    object.merge(changes) { _, new in new }
    return try APICoding.decoder().decode(
      UserDiveStatsRead.self, from: JSONSerialization.data(withJSONObject: object))
  }

  private let dahab = LocationRead(name: "Dahab, Egypt", latitude: 28.5, longitude: 34.5)
  private let moalboal = LocationRead(name: "Moalboal, Philippines", latitude: 9.9, longitude: 123.4)
  private let today = CalendarDate(year: 2026, month: 10, day: 8)!

  private func hero(
    _ stats: UserDiveStatsRead?, _ places: [LocationRead]? = [], units: UnitSystem = .metric
  ) -> HeroContent {
    ProfileSummary.hero(
      name: "Test Diver", stats: stats, places: places, units: units, today: today)
  }

  private func labels(_ hero: HeroContent) -> [String] { hero.figures.map(\.label) }

  private func value(_ label: String, _ hero: HeroContent) -> String?? {
    hero.figures.first { $0.label == label }.map(\.value)
  }

  /// "reads the logbook's totals, then where it went, then what it saw", and "shows the four
  /// figures the API derived".
  @Test func theTotalsThenWhereItWentThenWhatItSaw() throws {
    let hero = hero(try Self.stats(), [dahab, moalboal])
    #expect(hero.title == "Test Diver")
    #expect(
      labels(hero) == [
        "Total dives", "Max depth", "Total dive time", "Destinations", "Dive sites",
        "Species seen",
      ])
    #expect(value("Total dives", hero) == "212")
    #expect(value("Max depth", hero) == "39 m")
    #expect(value("Total dive time", hero) == "156h")
    #expect(value("Destinations", hero) == "2")
    #expect(value("Dive sites", hero) == "48")
    #expect(value("Species seen", hero) == "17")
    #expect(
      hero.points == [
        MapPoint(name: "Dahab, Egypt", latitude: 28.5, longitude: 34.5),
        MapPoint(name: "Moalboal, Philippines", latitude: 9.9, longitude: 123.4),
      ])
  }

  /// "rounds the time to whole hours past the first, and minutes under it".
  @Test func theTimeIsWholeHoursPastTheFirst() throws {
    #expect(value("Total dive time", hero(try Self.stats(["total_submerged_time": 563_460]))) == "157h")
    #expect(value("Total dive time", hero(try Self.stats(["total_submerged_time": 2400]))) == "40min")
  }

  @Test func theDepthIsInTheDiversUnits() throws {
    #expect(value("Max depth", hero(try Self.stats(), units: .imperial)) == "127 ft")
  }

  /// "counts the dive sites, and leaves them out at zero", "leaves Destinations out for a diver
  /// with no placed trips" and "leaves Species seen out for a diver who has logged none".
  @Test func aCountOfZeroIsLeftOut() throws {
    let hero = hero(try Self.stats(["dive_site_count": 0, "species_seen": 0]), [])
    #expect(labels(hero) == ["Total dives", "Max depth", "Total dive time"])
  }

  /// "are left out for a diver with no dives, but for their destinations".
  @Test func aLogbookWithNoDivesKeepsItsDestinations() throws {
    #expect(labels(hero(try Self.stats(["total_dives": 0]), [dahab])) == ["Destinations"])
  }

  /// "holds a dash while the stats are still loading": one per figure, the counts among them.
  @Test func unknownFiguresAreDashes() {
    let hero = hero(nil, nil)
    #expect(hero.figures.count == 6)
    #expect(hero.figures.allSatisfy { $0.value == nil })
    #expect(hero.facts.isEmpty)
  }

  /// "asks for no world while the places are still loading", and "falls back to the whole world
  /// when the places cannot be read".
  @Test func theWorldIsDrawnOnceThePlacesAreKnown() throws {
    #expect(!hero(try Self.stats(), nil).mapsTheWorldWhenEmpty)
    #expect(hero(try Self.stats(), []).mapsTheWorldWhenEmpty)
  }

  @Test func aPlaceWithNoPositionIsCountedButNotPinned() throws {
    let hero = hero(try Self.stats(), [dahab, LocationRead(name: "Somewhere")])
    #expect(value("Destinations", hero) == "2")
    #expect(hero.points.map(\.name) == ["Dahab, Egypt"])
  }

  /// "says when the logbook starts and when it was last added to".
  @Test func theLineSaysWhenTheLogbookStartsAndWasLastAddedTo() throws {
    #expect(
      hero(try Self.stats()).facts == [
        Fact(text: "Diving since 2014"), Fact(text: "Last dive 3 days ago"),
      ])
    #expect(hero(try Self.stats(["first_dive_on": NSNull(), "last_dive_on": NSNull()])).facts == [])
  }

  /// `getUserInitials`, and the person `UserAvatar` draws under two letters.
  @Test(
    arguments: [
      ("Test Diver", "TD"), ("anne marie smith", "AM"), ("Aleksei", nil), ("", nil),
      ("  Ana  Lopez ", "AL"),
    ] as [(String, String?)])
  func initials(name: String, expected: String?) {
    #expect(AvatarText.initials(name) == expected)
  }
}
