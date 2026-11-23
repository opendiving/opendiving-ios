import Foundation
import Testing

@testable import OpenDivingKit

/// What a download's notification says, from canned answers, and what a tap opens.
struct DiveComputerNoticeTests {
  private let perdix = "Shearwater Perdix 3"

  /// `import-pending.json` as an applied import whose rows have these outcomes and starts.
  private func answer(_ rows: [(outcome: String, start: String)]) throws -> LogbookImportRead {
    var json = try #require(
      try JSONSerialization.jsonObject(with: Data(KitFixture.text("import-pending").utf8))
        as? [String: Any])
    json["status"] = "applied"
    json["applied_at"] = "2026-11-07T12:00:00+00:00"
    let template = try #require((json["dives"] as? [[String: Any]])?.first)
    json["dives"] = rows.enumerated().map { index, row in
      var dive = template
      let uuid = String(format: "194fec2e-7413-58a1-a610-%012d", index)
      dive["uuid"] = uuid
      dive["outcome"] = row.outcome
      dive["start_time"] = row.start
      var read = try! #require(dive["dive"] as? [String: Any])
      read["uuid"] = uuid
      read["start_time"] = row.start
      dive["dive"] = read
      return dive
    }
    return try APICoding.decoder().decode(
      LogbookImportRead.self, from: JSONSerialization.data(withJSONObject: json))
  }

  /// What one import, the whole of its download, says.
  private func told(_ read: LogbookImportRead, from computer: String, units: UnitSystem)
    -> DiveComputerNotice?
  {
    DiveComputerNotice.imported(
      read.dives, imports: [read.uuid], download: UUID(), from: computer, units: units)
  }

  @Test func oneNewDiveNamesItsFactsAndOpensIt() throws {
    let read = try answer([("new", "2026-10-12T09:41:00+03:00")])
    let notice = try #require(told(read, from: perdix, units: .metric))
    #expect(notice.title == "1 new dive imported")
    #expect(
      notice.body == "12 October, 09:41 · 19.0 m · 51 min. Downloaded from Shearwater Perdix 3.")
    #expect(notice.target == .dive(try #require(read.dives.first?.uuid)))
    #expect(!notice.passive)
  }

  @Test func severalNewDivesNameTheirDaysAndOpenTheImport() throws {
    let spread = try answer([
      ("new", "2026-10-14T09:00:00+03:00"), ("new", "2026-10-13T09:00:00+03:00"),
      ("new", "2026-10-12T09:00:00+03:00"), ("unchanged", "2026-10-01T09:00:00+03:00"),
    ])
    let notice = try #require(told(spread, from: perdix, units: .metric))
    #expect(notice.title == "3 new dives imported")
    #expect(notice.body == "12–14 October. Downloaded from Shearwater Perdix 3.")
    #expect(notice.target == .importPage(spread.uuid))

    let oneDay = try answer([
      ("new", "2026-10-12T15:00:00+03:00"), ("new", "2026-10-12T09:00:00+03:00"),
    ])
    #expect(
      told(oneDay, from: perdix, units: .metric)?.body
        == "12 October. Downloaded from Shearwater Perdix 3.")
  }

  @Test func recordingsAloneArePassiveAndNameTheDives() throws {
    let one = try answer([("modified", "2026-10-12T09:41:00+03:00")])
    let notice = try #require(told(one, from: perdix, units: .metric))
    #expect(notice.title == "Recording added to 1 dive")
    #expect(notice.body == "Shearwater Perdix 3 also recorded your dive of 12 October, 09:41.")
    #expect(notice.passive)
    #expect(notice.target == .importPage(one.uuid))

    let three = try answer(Array(repeating: ("modified", "2026-10-12T09:41:00+03:00"), count: 3))
    let several = try #require(told(three, from: perdix, units: .metric))
    #expect(several.title == "Recordings added to 3 dives")
    #expect(several.body == "Shearwater Perdix 3 also recorded 3 dives already in your logbook.")
  }

  @Test func newDivesAndRecordingsTogetherTakeTheNewDivesTitle() throws {
    let read = try answer([
      ("new", "2026-10-12T09:41:00+03:00"), ("modified", "2026-10-11T09:41:00+03:00"),
      ("modified", "2026-10-10T09:41:00+03:00"),
    ])
    let notice = try #require(told(read, from: perdix, units: .metric))
    #expect(notice.title == "1 new dive imported")
    #expect(
      notice.body == "Recordings were added to 2 other dives. Downloaded from Shearwater Perdix 3.")
    #expect(notice.target == .importPage(read.uuid))
    let single = try answer([
      ("new", "2026-10-12T09:41:00+03:00"), ("modified", "2026-10-11T09:41:00+03:00"),
    ])
    #expect(
      told(single, from: perdix, units: .metric)?.body
        == "A recording was added to 1 other dive. Downloaded from Shearwater Perdix 3.")
  }

  @Test func aDownloadsImportsAreToldTogetherAndOpenTheDiveComputersScreen() throws {
    let first = try answer([("new", "2026-10-14T09:00:00+03:00")])
    let second = try answer([
      ("new", "2026-10-13T09:00:00+03:00"), ("unchanged", "2026-10-01T09:00:00+03:00"),
    ])
    let download = UUID()
    let notice = try #require(
      DiveComputerNotice.imported(
        first.dives + second.dives, imports: [first.uuid, second.uuid], download: download,
        from: perdix, units: .metric))
    #expect(notice.id == "import-" + download.uuidString.lowercased())
    #expect(notice.title == "2 new dives imported")
    #expect(notice.body == "13–14 October. Downloaded from Shearwater Perdix 3.")
    #expect(notice.target == .diveComputers)

    // One new dive among them opens it, whichever import made it.
    let unchanged = try answer([("unchanged", "2026-10-01T09:00:00+03:00")])
    let one = try #require(
      DiveComputerNotice.imported(
        unchanged.dives + first.dives, imports: [unchanged.uuid, first.uuid], download: download,
        from: perdix, units: .metric))
    #expect(one.target == .dive(try #require(first.dives.first?.uuid)))

    let recorded = try answer([("modified", "2026-10-12T09:41:00+03:00")])
    let recordings = try #require(
      DiveComputerNotice.imported(
        recorded.dives + recorded.dives, imports: [recorded.uuid, UUID()], download: download,
        from: perdix, units: .metric))
    #expect(recordings.passive)
    #expect(recordings.target == .diveComputers)
  }

  /// The dives of `read` at `indexes`, the ones the download took the computer's original to.
  private func updating(_ read: LogbookImportRead, _ indexes: [Int]) -> Set<UUID> {
    Set(indexes.compactMap { read.dives[$0].uuid })
  }

  @Test func updatedDivesAloneArePassiveAndNameTheirFacts() throws {
    let one = try answer([("modified", "2026-10-12T09:41:00+03:00")])
    let notice = try #require(
      DiveComputerNotice.imported(
        one.dives, imports: [one.uuid], download: UUID(), from: perdix,
        updating: updating(one, [0]), units: .metric))
    #expect(notice.title == "1 dive updated")
    #expect(
      notice.body == "12 October, 09:41 · 19.0 m · 51 min. Downloaded from Shearwater Perdix 3.")
    #expect(notice.passive)
    #expect(notice.target == .dive(try #require(one.dives.first?.uuid)))

    let three = try answer([
      ("modified", "2026-10-14T09:00:00+03:00"), ("modified", "2026-10-13T09:00:00+03:00"),
      ("modified", "2026-10-12T09:00:00+03:00"), ("unchanged", "2026-10-01T09:00:00+03:00"),
    ])
    let several = try #require(
      DiveComputerNotice.imported(
        three.dives, imports: [three.uuid], download: UUID(), from: perdix,
        updating: updating(three, [0, 1, 2, 3]), units: .metric))
    #expect(several.title == "3 dives updated")
    #expect(several.body == "12–14 October. Downloaded from Shearwater Perdix 3.")
    #expect(several.passive)
    #expect(several.target == .importPage(three.uuid))
  }

  @Test func updatedDivesBesideNewOnesOrRecordingsAreCountedInTheBody() throws {
    let new = try answer([
      ("new", "2026-10-12T09:41:00+03:00"), ("modified", "2026-10-11T09:41:00+03:00"),
    ])
    let withNew = try #require(
      DiveComputerNotice.imported(
        new.dives, imports: [new.uuid], download: UUID(), from: perdix,
        updating: updating(new, [1]), units: .metric))
    #expect(withNew.title == "1 new dive imported")
    #expect(
      withNew.body
        == "12 October, 09:41 · 19.0 m · 51 min. 1 other dive updated."
        + " Downloaded from Shearwater Perdix 3.")
    #expect(withNew.target == .dive(try #require(new.dives.first?.uuid)))
    #expect(!withNew.passive)

    let mixed = try answer([
      ("new", "2026-10-14T09:00:00+03:00"), ("new", "2026-10-13T09:00:00+03:00"),
      ("modified", "2026-10-11T09:41:00+03:00"), ("modified", "2026-10-10T09:41:00+03:00"),
      ("modified", "2026-10-09T09:41:00+03:00"), ("modified", "2026-10-08T09:41:00+03:00"),
    ])
    let all = try #require(
      DiveComputerNotice.imported(
        mixed.dives, imports: [mixed.uuid], download: UUID(), from: perdix,
        updating: updating(mixed, [3, 4, 5]), units: .metric))
    #expect(all.title == "2 new dives imported")
    #expect(
      all.body
        == "A recording was added to 1 other dive. 3 other dives updated."
        + " Downloaded from Shearwater Perdix 3.")

    // Recordings alone: no *Downloaded from*, so the count ends the body.
    let recorded = try answer([
      ("modified", "2026-10-12T09:41:00+03:00"), ("modified", "2026-10-11T09:41:00+03:00"),
    ])
    let recordings = try #require(
      DiveComputerNotice.imported(
        recorded.dives, imports: [recorded.uuid], download: UUID(), from: perdix,
        updating: updating(recorded, [1]), units: .metric))
    #expect(recordings.title == "Recording added to 1 dive")
    #expect(
      recordings.body
        == "Shearwater Perdix 3 also recorded your dive of 12 October, 09:41."
        + " 1 other dive updated.")
    #expect(recordings.passive)
  }

  /// A dive the download took the original to that the import left unchanged is told nowhere.
  @Test func anUnchangedDiveIsNotUpdated() throws {
    let read = try answer([("unchanged", "2026-10-12T09:41:00+03:00")])
    #expect(
      DiveComputerNotice.imported(
        read.dives, imports: [read.uuid], download: UUID(), from: perdix,
        updating: updating(read, [0]), units: .metric) == nil)
  }

  @Test func anImportOfNothingNewSaysNothing() throws {
    let read = try answer([("unchanged", "2026-10-12T09:41:00+03:00"), ("skipped", "2026-10-11")])
    #expect(told(read, from: perdix, units: .metric) == nil)
  }

  @Test func theWaitingNoticesOpenTheDiveComputersScreen() {
    let id = UUID()
    #expect(
      DiveComputerNotice.timeZone(dives: 1, from: perdix, id: id).body
        == "Downloaded from Shearwater Perdix 3. Tap to choose the time zone and import it.")
    #expect(
      DiveComputerNotice.noInternet(dives: 1, from: perdix, id: id).title == "1 dive downloaded")
    #expect(
      DiveComputerNotice.signedOut(dives: 1, from: perdix, id: id).title
        == "Sign in to import 1 dive")
    for notice in [
      DiveComputerNotice.timeZone(dives: 3, from: perdix, id: id),
      .noInternet(dives: 3, from: perdix, id: id), .signedOut(dives: 3, from: perdix, id: id),
    ] {
      #expect(notice.target == .diveComputers)
    }
  }

  @Test func aTargetTravelsInTheNotificationsOwnStrings() {
    let uuid = UUID()
    for target in [
      DiveComputerNotice.Target.dive(uuid), .importPage(uuid), .diveComputers,
    ] {
      #expect(DiveComputerNotice.Target(userInfo: target.userInfo) == target)
    }
    #expect(DiveComputerNotice.Target(userInfo: ["open": "dive"]) == nil)
    #expect(DiveComputerNotice.Target(userInfo: [:]) == nil)
  }
}
