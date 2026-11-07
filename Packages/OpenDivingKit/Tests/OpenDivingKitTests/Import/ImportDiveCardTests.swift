import Foundation
import OpenDivingKit
import Testing

/// Which rows of an import draw a card, what tapping one does, and what its sheet holds.
struct ImportDiveCardTests {
  private func read(_ fixture: String, _ edit: (inout [String: Any]) -> Void = { _ in }) throws
    -> LogbookImportRead
  {
    var row =
      try JSONSerialization.jsonObject(with: KitFixture.data(fixture)) as! [String: Any]
    edit(&row)
    return try APICoding.decoder().decode(
      LogbookImportRead.self, from: JSONSerialization.data(withJSONObject: row))
  }

  @Test func aReviewsCardOpensItsSheetWhateverTheRow() throws {
    for fixture in ["import-pending", "import-modified"] {
      let cards = ImportDiveCard.cards(
        try read(fixture).dives, applied: false, units: .metric)
      #expect(cards.map(\.tap) == [.sheet])
    }
  }

  @Test func aNewDivesSheetIsItsFieldsWithItsTanksAndRecordings() throws {
    let review = try read("import-pending")
    let card = try #require(
      ImportDiveCard.cards(review.dives, applied: false, units: .metric).first)
    #expect(card.accessibilityLabel.hasPrefix("New dive: "))
    guard case .info(let title, let sections) = card.sheet(units: .metric) else {
      Issue.record("not the info")
      return
    }
    #expect(title == card.content.title)
    let recordings = try #require(sections.first { $0.heading == "Recordings" })
    #expect(recordings.facts.map(\.label) == ["Recording 1"])
    #expect(recordings.facts[0].isWide)
    #expect(recordings.facts[0].value?.contains("Suunto Ocean") == true)
    #expect(recordings.facts[0].value?.contains("depth samples") == true)
    #expect(sections.contains { $0.heading == "Dive Info" })
    let dive = try #require(review.dives[0].dive)
    #expect(sections.contains { $0.heading == "Tanks" } == !dive.mixtures.isEmpty)
  }

  @Test func aModifiedDivesSheetListsItsChangesAndLinksNothingBeforeTheApply() throws {
    let review = try read("import-modified")
    let card = try #require(
      ImportDiveCard.cards(review.dives, applied: false, units: .metric).first)
    #expect(card.accessibilityLabel.hasPrefix("What changes on "))
    guard case .changes(_, let rows, let opens) = card.sheet(units: .metric) else {
      Issue.record("not the changes")
      return
    }
    #expect(rows.count == review.dives[0].changes.count)
    #expect(opens == nil)
  }

  /// A written import's before and after are nowhere else, so its modified card keeps its sheet
  /// and the sheet holds the way to the dive.
  @Test func anAppliedModifiedCardOpensItsSheetWithTheDiveInside() throws {
    let applied = try read("import-applied")
    let cards = ImportDiveCard.cards(applied.dives, applied: true, units: .metric)
    let card = try #require(cards.first)
    #expect(cards.count == 1)
    #expect(card.tap == .sheet)
    guard case .changes(_, _, let opens) = card.sheet(units: .metric) else {
      Issue.record("not the changes")
      return
    }
    #expect(opens == applied.dives[0].uuid)
  }

  @Test func anAppliedNewCardOpensItsDive() throws {
    let dives = try read("import-pending").dives
    let uuid = try #require(dives[0].uuid)
    #expect(ImportDiveCard.cards(dives, applied: true, units: .metric).map(\.tap) == [.dive(uuid)])
  }

  /// A row the apply reached with no reviewed row can have no uuid at all.
  @Test func anAppliedCardWithNoUUIDOpensNothing() throws {
    let unnamed = { (fixture: String) in
      try self.read(fixture) { object in
        var rows = object["dives"] as! [[String: Any]]
        rows[0]["uuid"] = NSNull()
        object["dives"] = rows
      }.dives
    }
    #expect(
      ImportDiveCard.cards(try unnamed("import-pending"), applied: true, units: .metric)
        .map(\.tap) == [.none])
    let modified = try #require(
      ImportDiveCard.cards(try unnamed("import-modified"), applied: true, units: .metric).first)
    #expect(modified.tap == .sheet)
    guard case .changes(_, _, let opens) = modified.sheet(units: .metric) else {
      Issue.record("not the changes")
      return
    }
    #expect(opens == nil)
  }

  @Test func onlyTheLogNamesARowWithNoCard() throws {
    #expect(!ImportDiveCard.leavesRowsOut(try read("import-pending").dives))
    #expect(ImportDiveCard.leavesRowsOut(try read("import-applied").dives))
  }
}
