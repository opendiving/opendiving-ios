import Foundation
import OpenDivingKit
import Testing

/// The trip's card, hero and information card over the `trip` fixture, as the web's
/// `tripFacts`, `tripFigures` and trip page print them.
struct TripSummaryTests {
  static func trip(_ changes: [String: Any] = [:]) throws -> TripRead {
    var object = try #require(
      JSONSerialization.jsonObject(with: KitFixture.data("trip")) as? [String: Any])
    object.merge(changes) { _, new in new }
    return try APICoding.decoder().decode(
      TripRead.self, from: JSONSerialization.data(withJSONObject: object))
  }

  static func contact(_ uuid: String, _ name: String) throws -> ContactRead {
    var object = try #require(
      JSONSerialization.jsonObject(with: KitFixture.data("contact")) as? [String: Any])
    object["uuid"] = uuid
    object["name"] = name
    return try APICoding.decoder().decode(
      ContactRead.self, from: JSONSerialization.data(withJSONObject: object))
  }

  private let hotel = "01a0e2ed-0000-7000-8000-0000000000a1"
  private let centre = "01a0e2ed-0000-7000-8000-0000000000a2"
  private let missing = "01a0e2ed-0000-7000-8000-0000000000a3"

  private var parts: [[String: Any]] {
    [
      [
        "start_date": "2024-06-01", "end_date": "2024-06-04",
        "location": ["name": "Dahab, Egypt", "latitude": 28.5, "longitude": 34.5],
        "accommodation_uuid": hotel, "candidate_count": 0,
      ],
      [
        "start_date": "2024-06-05", "end_date": "2024-06-08",
        "location": ["name": "Sharm"], "candidate_count": 0,
      ],
      ["candidate_count": 0],
    ]
  }

  @Test func theCardPrintsTheSpanTheFirstPlaceAndThreeFigures() throws {
    let trip = try Self.trip([
      "parts": parts, "dive_count": 12, "dive_site_count": 5, "species_count": 31,
      "max_depth": 31.6,
    ])
    let card = TripSummary.card(trip, units: .metric)
    #expect(card.title == "Dahab 2026 (September)")
    #expect(card.facts == [Fact(text: "Jun 1 - Jun 8, 2024"), Fact(text: "Dahab, Egypt +1")])
    #expect(
      card.figures == [
        Figure(label: "Dives", value: "12"), Figure(label: "Dive sites", value: "5"),
        Figure(label: "Species seen", value: "31"),
      ])
    let hero = TripSummary.hero(trip, units: .metric)
    #expect(hero.figures.last == Figure(label: "Max depth", value: "32 m"))
    #expect(hero.points == [MapPoint(name: "Dahab, Egypt", latitude: 28.5, longitude: 34.5)])
  }

  @Test func aPlaceCarriesItsFootprintToTheMap() throws {
    #expect(
      TripSummary.points(try Self.trip()) == [
        MapPoint(
          name: "Dahab, Egypt", latitude: 28.4963633, longitude: 34.5145652,
          bounds: LatLonBounds(
            south: 28.3363633, north: 28.6563633, west: 34.3545652, east: 34.6745652))
      ])
  }

  @Test func theCardAndTheHeroMapThePlacesOrTheWorld() throws {
    let trip = try Self.trip()
    let card = TripSummary.card(trip, units: .metric)
    #expect(card.points == TripSummary.points(trip))
    #expect(card.mapsTheWorldWhenEmpty)
    let hero = TripSummary.hero(trip, units: .metric)
    #expect(hero.points == TripSummary.points(trip))
    #expect(hero.mapsTheWorldWhenEmpty)
  }

  @Test func noSpeciesShowsTheDepthAndAnUndatedPlacelessTripHasNoFacts() throws {
    let trip = try Self.trip([
      "parts": [["candidate_count": 0]], "dive_count": 0, "dive_site_count": 0, "max_depth": 10,
    ])
    let card = TripSummary.card(trip, units: .imperial)
    #expect(card.facts.isEmpty)
    #expect(
      card.figures == [
        Figure(label: "Dives", value: "0"), Figure(label: "Dive sites", value: "0"),
        Figure(label: "Max depth", value: "33 ft"),
      ])
    let hero = TripSummary.hero(trip, units: .metric)
    #expect(hero.points.isEmpty)
    #expect(hero.mapsTheWorldWhenEmpty)
  }

  @Test func partHeadingsAreThePlaceOverTheDatesOrTheDatesAlone() throws {
    let trip = try Self.trip([
      "parts": [
        ["start_date": "2026-09-01", "location": ["name": "Bohol"], "candidate_count": 0],
        ["end_date": "2021-04-06", "candidate_count": 0],
        ["candidate_count": 0],
      ]
    ])
    let headings = trip.parts.map(TripSummary.partHeading)
    #expect(headings[0].title == "Bohol")
    #expect(headings[0].subtitle == "From Sep 1, 2026")
    #expect(headings[1].title == "Until Apr 6, 2021")
    #expect(headings[1].subtitle == nil)
    #expect(headings[2].title == "No place recorded")
  }

  @Test func theInformationCardNamesTheContactsItCanRead() throws {
    let trip = try Self.trip(["parts": parts, "contact_uuids": [centre, missing, hotel]])
    let contacts = Dictionary(
      uniqueKeysWithValues: try [
        Self.contact(hotel, "Hotel Nemo"), Self.contact(centre, "Big Blue"),
      ]
      .map { ($0.uuid, $0) })
    #expect(
      TripSummary.partRows(trip, contacts: contacts) == [
        .init(place: "Dahab, Egypt", accommodation: "Hotel Nemo", dates: "Jun 1 - Jun 4, 2024"),
        .init(place: "Sharm", dates: "Jun 5 - Jun 8, 2024"),
        .init(),
      ])
    #expect(TripSummary.diveCenters(trip, contacts: contacts) == "Big Blue, Hotel Nemo")
    #expect(TripSummary.diveCenters(trip, contacts: [:]) == nil)
    #expect(
      TripSummary.contactUUIDs(trip).map { $0.uuidString.lowercased() } == [hotel, centre, missing])
  }

  // MARK: - Info

  @Test func recordInfoListsTheTripsFieldsWithOnePart() throws {
    let info = TripSummary.recordInfo(try Self.trip())
    #expect(info.map(\.heading) == [nil, "Part", nil])
    #expect(info[0].facts == [RecordInfoFact(label: "Name", value: "Dahab 2026 (September)")])
    #expect(
      info[1].facts == [
        RecordInfoFact(label: "Location", value: "Dahab, Egypt"),
        RecordInfoFact(label: "Start date", value: "Sep 6, 2026"),
        RecordInfoFact(label: "End date", value: nil),
      ])
    #expect(info[2].facts == [RecordInfoFact(label: "Notes", value: nil, isWide: true)])
  }

  @Test func recordInfoNumbersManyPartsAndKeepsARowForNone() throws {
    let part: [String: Any] = ["candidate_count": 0]
    let many = TripSummary.recordInfo(try Self.trip(["parts": [part, part]]))
    #expect(many.map(\.heading) == [nil, "Part 1", "Part 2", nil])
    let none = TripSummary.recordInfo(try Self.trip(["parts": []]))
    #expect(none[1] == RecordInfoSection(facts: [RecordInfoFact(label: "Parts", value: nil)]))
  }
}
