import Foundation
import Testing

@testable import OpenDivingKit

/// The gear list's cards and a gear item's head say what the web's say: rows from the web's
/// `gear-cards.render.test.tsx` and `gear-item-hero.render.test.tsx` at its pin.
struct GearContentTests {
  private let today = CalendarDate(iso8601: "2026-08-10")!

  private func json(_ name: String, _ overrides: [String: Any]) throws -> Data {
    var object = try #require(
      JSONSerialization.jsonObject(with: KitFixture.data(name)) as? [String: Any])
    object.merge(overrides) { $1 }
    return try JSONSerialization.data(withJSONObject: object)
  }

  private func item(_ overrides: [String: Any] = [:]) throws -> GearItemRead {
    let base: [String: Any] = [
      "name": "MK25 EVO", "brand": NSNull(), "type": NSNull(), "volume": NSNull(),
      "working_pressure": NSNull(), "material": NSNull(), "dive_count": 12,
      "dive_time": 43200,
    ]
    return try APICoding.decoder().decode(
      GearItemRead.self, from: json("gear-item", base.merging(overrides) { $1 }))
  }

  private func set(_ overrides: [String: Any] = [:]) throws -> GearSetRead {
    let base: [String: Any] = ["name": "Warm water rig", "weight": NSNull(), "gear_items": []]
    return try APICoding.decoder().decode(
      GearSetRead.self, from: json("gear-set", base.merging(overrides) { $1 }))
  }

  private static func schedule(_ fields: [String: Any]) -> [String: Any] {
    ["uuid": "01a14b2e-0c3d-7a10-9f00-7a2b3c4d5e6f", "kind": "service", "is_active": true]
      .merging(fields) { $1 }
  }

  private func card(_ item: GearItemRead, _ units: UnitSystem = .metric) -> PlainCardContent {
    .gearItem(item, units: units, today: today)
  }

  private func figure(_ figures: [Figure], _ label: String) -> String? {
    figures.first { $0.label == label }?.value
  }

  @Test func theServiceBadgeTakesTheWebsVariants() {
    #expect(GearServiceStatus.overdue.badgeStyle == .destructive)
    #expect(GearServiceStatus.dueSoon.badgeStyle == .coral)
    #expect(GearServiceStatus.ok.badgeStyle == .teal)
    #expect(GearServiceStatus.dueSoon.badge == Badge("Due soon", style: .coral))
  }

  @Test func anItemsCardSaysWhatItIsACylindersFactsIncluded() throws {
    let cylinder = try item([
      "type": "cylinder", "brand": "Faber", "volume": 12, "working_pressure": 232,
      "material": "steel",
    ])
    #expect(
      card(cylinder).facts.compactMap(\.text) == ["Cylinder", "Faber", "12 L", "232 bar", "Steel"])
    let preset = try item([
      "type": "cylinder", "brand": "Luxfer", "volume": 11.1, "working_pressure": 207,
      "material": "aluminium",
    ])
    #expect(
      card(preset).facts.compactMap(\.text) == [
        "Cylinder", "Luxfer", "AL80", "11.1 L", "207 bar", "Aluminium",
      ])
  }

  @Test func anItemsCardCarriesWhatItHasBeenDived() throws {
    let content = card(try item())
    #expect(content.title == "MK25 EVO")
    #expect(figure(content.figures, "Dives") == "12")
    #expect(figure(content.figures, "Dive time") == "12h")
  }

  @Test func anItemsCardBadgesRentedArchivedAndItsServiceOnlyWhereTracked() throws {
    let both = card(try item(["rented": true, "is_archived": true]))
    #expect(both.badges == [Badge("Rented", style: .outline), Badge("Archived", style: .outline)])
    let tracked = card(
      try item([
        "dive_count": 120,
        "service": [Self.schedule(["interval_dives": 100, "next_due_at_dive_count": 100])],
      ]))
    #expect(tracked.badges == [Badge("Overdue", style: .destructive)])
    #expect(card(try item()).badges.isEmpty)
  }

  @Test func aSetsCardListsItsKitAndItsBallast() throws {
    let content = PlainCardContent.gearSet(
      try set([
        "weight": 4,
        "gear_items": [
          [
            "uuid": "01a14b2e-0c3d-7a10-9f00-5a2b3c4d5e61", "name": "MK25 EVO",
            "brand": "Scubapro", "rented": false, "is_archived": false,
          ],
          [
            "uuid": "01a14b2e-0c3d-7a10-9f00-5a2b3c4d5e62", "name": "Hydros Pro",
            "brand": "Scubapro", "rented": false, "is_archived": false,
          ],
        ],
      ]), units: .metric)
    #expect(content.facts.compactMap(\.text) == ["Scubapro MK25 EVO", "Scubapro Hydros Pro"])
    #expect(content.emptyLine == nil)
    #expect(figure(content.figures, "Items") == "2")
    #expect(figure(content.figures, "Weight") == "4 kg")
  }

  @Test func anEmptySetSaysSoAndDashesTheWeightItDoesNotCarry() throws {
    let content = PlainCardContent.gearSet(try set(), units: .metric)
    #expect(content.facts.isEmpty)
    #expect(content.emptyLine == "Empty")
    #expect(figure(content.figures, "Items") == "0")
    #expect(figure(content.figures, "Weight") == .some(nil))
  }

  private func hero(_ item: GearItemRead, _ units: UnitSystem = .metric) -> HeroContent {
    GearItemPageContent.hero(item, units: units, today: today)
  }

  private let al80: [String: Any] = [
    "name": "AL80", "type": "cylinder", "volume": 11.1, "working_pressure": 207,
    "material": "aluminium", "dive_count": 0, "dive_time": 0,
  ]

  @Test func theHeadStatesACylindersFactsBesideItsDives() throws {
    let content = hero(try item(al80))
    #expect(figure(content.figures, "Cylinder") == "AL80 · 11.1 L · 207 bar · Aluminium")
    #expect(figure(content.figures, "Dives") == "0")
    #expect(figure(content.figures, "Dive time") == "0min")
    #expect(content.figures.map(\.label) == ["Cylinder", "Dives", "Dive time"])
  }

  @Test func theHeadLeadsAnUnnamedCylinderWithCubicFeetUnderImperial() throws {
    let content = hero(try item(al80.merging(["material": "steel"]) { $1 }), .imperial)
    #expect(figure(content.figures, "Cylinder")?.hasPrefix("80 cu ft · 11.1 L · ") == true)
  }

  @Test func theHeadStatesNoCylinderForAnItemRecordingNoFacts() throws {
    let content = hero(try item(["type": "regulator"]))
    #expect(figure(content.figures, "Cylinder") == nil)
    #expect(content.facts.compactMap(\.text) == ["Regulator"])
  }

  @Test func theHeadSaysTheDiveTimeInHoursAndMinutes() throws {
    #expect(
      figure(hero(try item(["dive_count": 3, "dive_time": 8100])).figures, "Dive time")
        == "2h 15min")
  }

  @Test func theHeadCountsTheNextServiceInHoursOfDiving() throws {
    let content = hero(
      try item([
        "dive_count": 1, "dive_time": 2700,
        "service": [Self.schedule(["interval_hours": 1, "next_due_at_dive_time": 6300])],
      ]))
    #expect(figure(content.figures, "Next service") == "In 1 hour of diving")
    let overdue = hero(
      try item([
        "dive_count": 1, "dive_time": 7200,
        "service": [Self.schedule(["next_due_at_dive_time": 6300])],
      ]))
    #expect(figure(overdue.figures, "Next service") == "Overdue")
  }

  @Test func theNextServiceOnADateIsTheDate() throws {
    let content = hero(try item(["service": [Self.schedule(["next_due_on": "2027-01-05"])]]))
    #expect(figure(content.figures, "Next service") == "Jan 5, 2027")
  }

  @Test func theHeadsSubtitleNamesRentedAndArchived() throws {
    let content = hero(
      try item(["type": "regulator", "brand": "Scubapro", "rented": true, "is_archived": true]))
    #expect(content.facts.compactMap(\.text) == ["Regulator", "Scubapro", "Rented", "Archived"])
  }

  @Test func aCopyOfASetIsNamedACopy() throws {
    let source = try KitFixture.decode(GearSetRead.self, "gear-set")
    let copy = GearSetFormValues(duplicating: source)
    #expect(copy.name == "Warm water copy")
    #expect(copy.weight == 4)
    #expect(copy.items == source.gearItems.map(\.ref))
  }

  @Test func archivingQueuesTheArchiveAndUnarchivingTheReturn() throws {
    let active = try item()
    #expect(
      GearItemDetailModel.archiveToggle(active)
        == .updateGearItem(.server(active.uuid), GearItemUpdate(archived: true)))
    #expect(GearItemDetailModel.offersArchiveInstead(active))
    let archived = try item(["is_archived": true])
    #expect(
      GearItemDetailModel.archiveToggle(archived)
        == .updateGearItem(.server(archived.uuid), GearItemUpdate(archived: false)))
    #expect(!GearItemDetailModel.offersArchiveInstead(archived))
  }
}
