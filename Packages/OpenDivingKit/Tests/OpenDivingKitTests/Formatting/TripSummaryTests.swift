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
    #expect(TripSummary.hero(trip, units: .metric).points.isEmpty)
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
      uniqueKeysWithValues: try [Self.contact(hotel, "Hotel Nemo"), Self.contact(centre, "Big Blue")]
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
}
