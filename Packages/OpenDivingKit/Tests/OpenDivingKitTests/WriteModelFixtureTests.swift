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

  @Test func placesAndSiteSuggestionsCarryTheirAttribution() throws {
    let places = try KitFixture.roundTrip([GeocodeResult].self, "geocode-search")
    #expect(places.first?.location == "Dahab, South Sinai, Egypt")
    #expect(places.first?.attribution.contains("OpenStreetMap") == true)
    let sites = try KitFixture.roundTrip(DiveSiteSuggestResponse.self, "dive-site-suggest")
    #expect(sites.hasMore)
    #expect(sites.results.first?.heldSite?.name == "Thistlegorm")
    #expect(sites.results.first?.externalId.identifier == "node/255316037")
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

  @Test func anImportPreviewReadsCodesItHasNeverSeen() throws {
    let preview = try KitFixture.roundTrip(ImportPreview.self, "import-preview")
    #expect(preview.members.map(\.name) == ["dive-0214.fit", "notes.txt"])
    #expect(preview.members.last?.refusal == "This file is not one OpenDiving reads.")
    #expect(preview.dives.first?.notes.last?.code == "a_code_from_a_newer_reader")
    #expect(preview.dives.first?.notes.last?.kind == "something_new")
    #expect(preview.dives.last?.startTime == DiveTimestamp(wireValue: "2026-09-13"))
    #expect(preview.dives.first?.device?.model == "Descent Mk3")
    #expect(preview.token == "eyJhbGciOiJIUzI1NiJ9.example.signature")
    #expect(
      preview.checkInDetails.first == .email(account: nil, proposed: "desk@example.org"))
    #expect(preview.portrait?.accountSha256 == nil)
  }

  @Test func anImportResult() throws {
    let result = try KitFixture.roundTrip(ImportResult.self, "import-result")
    #expect(result.dives.first?.uuid != nil)
    #expect(result.collections.first?.created == 1)
  }

  @Test func aCheckInDetailThisVersionDoesNotKnowKeepsThePreviewReadable() throws {
    let details = try APICoding.decoder().decode(
      [ImportCheckInDetail].self,
      from: Data(#"[{"detail":"blood_type","account":null,"proposed":"O+"}]"#.utf8))
    #expect(details == [.other("blood_type")])
  }
}
