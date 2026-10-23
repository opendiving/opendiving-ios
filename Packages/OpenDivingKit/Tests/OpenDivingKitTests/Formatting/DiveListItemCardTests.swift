import Foundation
import OpenDivingKit
import Testing

/// The list row's card is the seventeen-argument mapping filled from the row's own fields.
struct DiveListItemCardTests {
  /// The `dives-page` fixture's one row, with `changes` laid over its JSON.
  private func item(_ changes: [String: Any] = [:]) throws -> DiveListItem {
    let page = try #require(
      JSONSerialization.jsonObject(with: KitFixture.data("dives-page")) as? [String: Any])
    var row = try #require((page["data"] as? [[String: Any]])?.first)
    row.merge(changes) { _, new in new }
    return try APICoding.decoder().decode(
      DiveListItem.self, from: JSONSerialization.data(withJSONObject: row))
  }

  @Test func fillsTheCardFromTheRow() throws {
    let site: [String: Any] = [
      "uuid": "01a0e2ed-0000-7000-8000-000000000001", "name": "Blue Hole",
      "location": ["name": "Dahab"],
    ]
    let second: [String: Any] = ["uuid": "01a0e2ed-0000-7000-8000-000000000002", "name": "Canyon"]
    let row = try item([
      "dive_sites": [site, second], "course_uuid": "01a0e2ed-0000-7000-8000-000000000003",
      "rating": 4, "water_type": "fresh", "type": "closed_circuit", "tags": ["wreck"],
      "boat_name": "Blue Seas",
    ])
    let expected = DiveCardContent.dive(
      number: 532, siteNames: ["Blue Hole", "Canyon"], isCourse: true, rating: 4,
      waterType: "fresh", diveType: "closed_circuit", tags: ["wreck"], start: row.startTime,
      locationName: "Dahab", boatName: "Blue Seas", hasRecording: true, submergedSeconds: 3243,
      maxDepth: 23.41, avgDepth: 13.62, waterTemperature: 27.2,
      outline: [321, 449, 685, 972, 1346, 1643, 1690, 1727, 1987, 2269, 2341, 2177],
      units: .imperial)
    #expect(DiveCardContent.dive(row, units: .imperial) == expected)
    #expect(expected.title == "#532 Blue Hole +1")
  }

  @Test func noRecordingAndNoOutline() throws {
    let card = DiveCardContent.dive(
      try item(["recording_count": 0, "depth_outline": NSNull()]), units: .metric)
    #expect(card.outline.isEmpty)
    #expect(!card.facts.contains { $0.systemImage == "paperclip" })
    #expect(card.title == "Dive #532")
    #expect(!card.isCourse)
  }
}
