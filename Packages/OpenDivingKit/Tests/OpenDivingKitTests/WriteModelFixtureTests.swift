import Foundation
import OpenDivingKit
import Testing

/// The responses the write, lookup and import routes answer decode their fixtures and survive
/// an encode-and-decode unchanged.
struct WriteModelFixtureTests {
  @Test func theSixLookupsAreLookupRows() throws {
    let sites = try KitFixture.roundTrip(
      PaginatedListResponse<DiveSiteLookupItem>.self, "lookup-dive-sites")
    #expect(sites.data.map(\.subtitle) == ["Dahab, South Sinai, Egypt", nil])
    #expect(sites.data.first?.entryTypes == ["shore", "boat"])
    #expect(sites.data.allSatisfy { !$0.ref.isLocal })
    #expect(sites.data.map(\.isCommons) == [false, true])
    #expect(sites.data.last?.saved == false)
    #expect(sites.data.last?.attribution?.contains("OpenStreetMap") == true)
    #expect(sites.data.last?.otherNames == ["Old Quarry"])
    #expect(sites.data.last?.externalIds.first?.identifier == "node/255316037")
    #expect(sites.data.first?.latitude == 28.5021)

    let trips = try KitFixture.roundTrip(PaginatedListResponse<TripLookupItem>.self, "lookup-trips")
    #expect(trips.data.first?.people.first?.role == "companion")

    let people = try KitFixture.roundTrip(
      PaginatedListResponse<PersonLookupItem>.self, "lookup-people")
    #expect(people.data.map(\.subtitle) == ["ana", nil])

    let courses = try KitFixture.roundTrip(
      PaginatedListResponse<CourseLookupItem>.self, "lookup-courses")
    #expect(courses.data.first?.contact?.serverUUID != nil)

    let contacts = try KitFixture.roundTrip(
      PaginatedListResponse<ContactLookupItem>.self, "lookup-contacts")
    #expect(contacts.data.map(\.subtitle) == ["Dahab, Egypt", nil])

    let gear = try KitFixture.roundTrip(
      PaginatedListResponse<GearItemLookupItem>.self, "lookup-gear-items")
    #expect(gear.data.first?.title == "12 L steel")
    #expect(gear.data.first?.subtitle == "Example Cylinders")
  }

  @Test func gearSetsKeepTheirOrderAndTheirArchivedItems() throws {
    let page = try KitFixture.roundTrip(PaginatedListResponse<GearSetRead>.self, "gear-sets-page")
    let set = try #require(page.data.first)
    #expect(set.gearItems.map(\.name) == ["Shorty 3 mm", "12 L steel"])
    #expect(set.gearItems.last?.isArchived == true)
    #expect(set.weight == 4)
  }

  @Test func aCreatedGearItem() throws {
    let item = try KitFixture.roundTrip(GearItemRead.self, "gear-item")
    #expect(item.workingPressure == 232)
    #expect(item.archivedAt == nil)
  }

  @Test func theFormsSuggestions() throws {
    let number = try KitFixture.roundTrip(DiveNumberSuggestion.self, "dive-number-suggestion")
    #expect(number.diveNumber == 215)
    #expect(!number.isTaken)
    #expect(
      try KitFixture.roundTrip(RecentVolumes.self, "recent-volumes").volumes == [11.1, 15, 12])
    let species = try KitFixture.roundTrip(SpeciesSuggestResponse.self, "species-suggest")
    #expect(species.results.map(\.uuid?.uuidString.isEmpty) == [false, nil])
    #expect(species.results.last?.matchedName == "Manta birostris")
    #expect(species.results.first?.lastSeen?.utcOffsetMinutes == 180)
  }

  @Test func placesCarryTheirAttribution() throws {
    let places = try KitFixture.roundTrip([GeocodeResult].self, "geocode-search")
    #expect(places.first?.location == "Dahab, South Sinai, Egypt")
    #expect(places.first?.attribution.contains("OpenStreetMap") == true)
  }

  @Test func aPageOfTags() throws {
    let page = try KitFixture.roundTrip(PaginatedListResponse<TagRead>.self, "tags-page")
    #expect(page.data.map(\.name) == ["night", "wall"])
    #expect(page.data.last?.siteCount == 2)
    #expect(page.data.map(TagsModel.usage) == ["12 dives", "1 dive, 2 sites"])
  }

  @Test func storage() throws {
    let storage = try KitFixture.roundTrip(StorageUsageRead.self, "storage")
    #expect(storage.usedBytes == 137_512_960)
    #expect(storage.limitBytes == 1_073_741_824)
  }

  @Test func aDraftAndAPageOfThem() throws {
    let draft = try KitFixture.roundTrip(DiveDraftRead.self, "dive-draft")
    #expect(draft.values.waterType == "salt")
    #expect(draft.values.diveNumber == nil)
    #expect(draft.write.gearSet == draft.gearSetUuid.map(RecordRef.server))
    #expect(draft.write.values == draft.values)
    let page = try KitFixture.roundTrip(
      PaginatedListResponse<DiveDraftRead>.self, "dive-drafts-page")
    #expect(page.data.first?.gearSetUuid == nil)
  }

  @Test func aPendingImport() throws {
    let pending = try KitFixture.roundTrip(LogbookImportRead.self, "import-pending")
    #expect(!pending.isApplied)
    #expect(pending.appliedAt == nil)
    #expect(pending.expiresAt != nil)
    #expect(pending.members.map(\.name) == ["dive-0214.fit", "notes.txt"])
    #expect(pending.members.last?.refusal == "This file is not one OpenDiving reads.")
    let row = try #require(pending.dives.first)
    #expect(row.outcome == "new")
    #expect(row.dive?.dive.maxDepth == 19.04)
    #expect(row.device?.model == "Suunto Ocean")
    #expect(row.changes.isEmpty)
    #expect(pending.checkInDetails.first == .email(account: nil, proposed: "desk@example.org"))
    #expect(pending.portrait == nil)
    #expect(pending.numbering.totalDives == 0)
  }

  @Test func aModifiedDiveCarriesItsChanges() throws {
    let modified = try KitFixture.roundTrip(LogbookImportRead.self, "import-modified")
    let row = try #require(modified.dives.first)
    #expect(row.outcome == "modified")
    let change = { (member: String) in row.changes.first { $0.member == member } }
    #expect(change("entry_latitude")?.before == .null)
    #expect(change("entry_latitude")?.after == .number(28.496525))
    #expect(change("recordings/0/device/name")?.after == .string("Ocean"))
    #expect(change("recordings/0/profile/duration")?.before == .number(3_473_000))
    guard case .object(let file) = change("recordings/0/files/1")?.after else {
      Issue.record("A file added is an object")
      return
    }
    // The API's own keys, not the camelCase the models' keys become.
    #expect(file["original_filename"] == .string("dive-0214.json"))
    #expect(file["updated_at"] == .null)
  }

  @Test func aChangeHoldsAnyJSONAndSurvivesTheEncoder() throws {
    let json = Data(
      #"""
      {"member":"tags","before":[1,true,"a",null,{"snake_case":[]}],"after":false}
      """#.utf8)
    let change = try APICoding.decoder().decode(LogbookImportChange.self, from: json)
    #expect(
      change.before
        == .array([
          .number(1), .bool(true), .string("a"), .null, .object(["snake_case": .array([])]),
        ]))
    #expect(change.after == .bool(false))
    let again = try APICoding.decoder().decode(
      LogbookImportChange.self, from: APICoding.encoder().encode(change))
    #expect(again == change)
  }

  @Test func anAppliedImportEndsWithARowTheReviewDidNotShow() throws {
    let applied = try KitFixture.roundTrip(LogbookImportRead.self, "import-applied")
    #expect(applied.isApplied)
    #expect(applied.appliedAt != nil)
    #expect(applied.dives.first?.uuid != nil)
    #expect(applied.dives.last?.uuid == nil)
    #expect(applied.dives.last?.outcome == "skipped")
  }

  @Test func theLogReadsCodesItHasNeverSeen() throws {
    let log = try KitFixture.roundTrip(LogbookImportNotes.self, "import-notes")
    let row = try #require(log.dives.last)
    #expect(row.uuid == nil)
    #expect(row.outcome == "skipped")
    #expect(row.reason != nil)
    #expect(row.notes.map(\.code) == ["review_unshown", "a_code_from_a_newer_reader"])
    #expect(row.notes.last?.kind == "something_new")
    #expect(row.notesTruncated == 2)
    #expect(log.notes.first?.count == 1)
    #expect(log.notesTruncated == 1)
  }

  @Test func theHistoryCountsByOutcome() throws {
    let page = try KitFixture.roundTrip(
      PaginatedListResponse<LogbookImportSummary>.self, "imports-page")
    #expect(page.data.map(\.counts) == [["modified": 1], ["new": 1]])
    #expect(page.hasMore == false)
  }

  @Test func aCheckInDetailThisVersionDoesNotKnowKeepsTheImportReadable() throws {
    let details = try APICoding.decoder().decode(
      [ImportCheckInDetail].self,
      from: Data(#"[{"detail":"blood_type","account":null,"proposed":"O+"}]"#.utf8))
    #expect(details == [.other("blood_type")])
  }
}
