import Foundation
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The reads of More's records: each route asked as the API takes it, each answer decoded
/// from its fixture, a vocabulary this build does not know read as the string it is.
struct MoreRecordReadsTests {
  private let item = UUID(uuidString: "01a14b2e-0c3d-7a10-9f00-1a2b3c4d5e6f")!

  /// Every read, each answered with its fixture, and the requests sent.
  @Test func everyReadAsksItsRoute() async throws {
    let wire = item.uuidString.lowercased()
    let fixtures: [String: String] = [
      "GET gear-items": "gear-items-page",
      "GET gear-item/\(wire)": "gear-item",
      "GET gear-set/\(wire)": "gear-set",
      "GET gear-service-schedules": "gear-service-schedules-page",
      "GET gear-service-schedule/\(wire)": "gear-service-schedule",
      "GET gear-service-records": "gear-service-records-page",
      "GET gear-service-record/\(wire)": "gear-service-record",
      "GET courses": "courses-page",
      "GET certification/\(wire)": "certification-front-only",
      "GET person/\(wire)": "person",
      "GET contacts": "contacts-page",
      "GET user/species/\(wire)": "species-life-list-entry",
      "GET dives": "dives-page",
    ]
    let texts = try fixtures.mapValues { try KitFixture.text($0) }
    let harness = ClientHarness(accessToken: "live") { request in
      if request.route == "GET certifications" { return .emptyPage }
      return texts[request.route].map { .json($0) }
        ?? .json(#"{"detail":"Not Found"}"#, status: 404)
    }
    let client = harness.client
    _ = try await client.gearItems(page: 2, includeArchived: true)
    _ = try await client.gearItem(item)
    _ = try await client.gearSet(item)
    _ = try await client.gearServiceSchedules(gearItemUUID: item, page: 1)
    _ = try await client.gearServiceSchedule(item)
    _ = try await client.gearServiceRecords(gearItemUUID: item, page: 1)
    _ = try await client.gearServiceRecord(item)
    _ = try await client.courses(page: 1)
    _ = try await client.certifications(courseUUID: item, page: 1)
    _ = try await client.certification(item)
    _ = try await client.person(item)
    _ = try await client.contacts(page: 1)
    _ = try await client.lifeListEntry(item)
    for scope in [
      DiveListScope.gearItem(item), .course(item), .person(item), .species(item),
    ] {
      _ = try await client.dives(scope, page: 1)
    }

    let sent = harness.transport.requests.map { request in
      let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.query
      return request.route + (query.map { "?" + $0 } ?? "")
    }
    #expect(
      sent == [
        "GET gear-items?page=2&items_per_page=50&include_archived=true",
        "GET gear-item/\(wire)",
        "GET gear-set/\(wire)",
        "GET gear-service-schedules?gear_item_uuid=\(wire)&page=1&items_per_page=100",
        "GET gear-service-schedule/\(wire)",
        "GET gear-service-records?gear_item_uuid=\(wire)&page=1&items_per_page=100",
        "GET gear-service-record/\(wire)",
        "GET courses?page=1&items_per_page=50",
        "GET certifications?page=1&items_per_page=100&course_uuid=\(wire)",
        "GET certification/\(wire)",
        "GET person/\(wire)",
        "GET contacts?page=1&items_per_page=50",
        "GET user/species/\(wire)",
        "GET dives?page=1&items_per_page=100&gear_item_uuid=\(wire)",
        "GET dives?page=1&items_per_page=100&course_uuid=\(wire)",
        "GET dives?page=1&items_per_page=100&person_uuid=\(wire)",
        "GET dives?page=1&items_per_page=100&species_uuid=\(wire)",
      ])
    #expect(harness.transport.requests.allSatisfy { $0.bearer == "live" })
  }

  @Test func gearDecodesWithItsServiceAndUnknownVocabulary() throws {
    let page = try KitFixture.roundTrip(PaginatedListResponse<GearItemRead>.self, "gear-items-page")
    #expect(page.data.map(\.name) == ["MK25 EVO / S620Ti", "12 L steel", "Hookah hose"])
    #expect(page.data[0].service.first?.nextDueAtDiveCount == 140)
    #expect(page.data[1].isArchived)
    #expect(page.data[1].service.first?.kind == "oxygen_clean")
    #expect(page.data[1].service.first?.isActive == false)
    #expect(page.data[2].type == "hookah")
    #expect(page.data[2].material == "titanium")
    let set = try KitFixture.roundTrip(GearSetRead.self, "gear-set")
    #expect(set.gearItems.map(\.name) == ["Shorty 3 mm"])
  }

  @Test func serviceDecodesWithAnUnknownKind() throws {
    let schedules = try KitFixture.roundTrip(
      PaginatedListResponse<GearServiceScheduleRead>.self, "gear-service-schedules-page")
    #expect(schedules.data.map(\.kind) == ["service", "rebuild"])
    #expect(schedules.data[0].startsOn == CalendarDate(year: 2025, month: 9, day: 1))
    #expect(schedules.data[1].nextDueAtDiveTime == 540_000)
    let schedule = try KitFixture.roundTrip(GearServiceScheduleRead.self, "gear-service-schedule")
    #expect(schedule == schedules.data[0])
    let records = try KitFixture.roundTrip(
      PaginatedListResponse<GearServiceRecordRead>.self, "gear-service-records-page")
    #expect(records.data.map(\.kind) == ["service", "sonic_clean"])
    #expect(records.data[0].contactUuid != nil)
    #expect(records.data[1].gearServiceScheduleUuid == nil)
    let record = try KitFixture.roundTrip(GearServiceRecordRead.self, "gear-service-record")
    #expect(record == records.data[0])
  }

  @Test func trainingPeopleAndContactsDecode() throws {
    let courses = try KitFixture.roundTrip(PaginatedListResponse<CourseRead>.self, "courses-page")
    #expect(courses.data.map(\.status) == ["completed", "deferred"])
    #expect(courses.data[1].agencyOther == "Cave Federation")
    let person = try KitFixture.roundTrip(PersonRead.self, "person")
    #expect(person.diveCount == 3)
    let contacts = try KitFixture.roundTrip(
      PaginatedListResponse<ContactRead>.self, "contacts-page")
    #expect(contacts.data[1].roles == ["liveaboard_operator"])
    #expect(contacts.data[1].address == nil)
  }

  @Test func aSpeciesCarriesItsTaxonomyAndItsHistory() throws {
    let species = try KitFixture.roundTrip(SpeciesRead.self, "species")
    #expect(species.aphiaId == 278400)
    #expect(species.className == "Teleostei")
    #expect(species.orderName == "Ovalentaria incertae sedis")
    #expect(species.isMarine == true)
    #expect(species.wikidataQid == "Q1207627")
    let entry = try KitFixture.roundTrip(SpeciesLifeListEntry.self, "species-life-list-entry")
    #expect(entry.diveSiteCount == 3)
  }
}
