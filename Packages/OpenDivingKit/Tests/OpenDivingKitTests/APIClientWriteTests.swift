import Foundation
import OpenDivingKit
import Synchronization
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

struct APIClientWriteTests {
  private static let message = StubTransport.Response.json(#"{"message":"Updated"}"#)
  private let key = UUID()
  private let uuid = UUID(uuidString: "01A14B2E-0C3D-7A10-9F00-AA2B3C4D5E6F")!

  private func dive() throws -> DiveCreate {
    try APICoding.decoder().decode(DiveCreate.self, from: KitFixture.data("request-dive-create"))
  }

  /// A harness answering every route from `routes`, by `"METHOD path"`.
  private func harness(_ routes: [String: StubTransport.Response]) -> ClientHarness {
    ClientHarness(accessToken: "live") { request in
      routes[request.route] ?? .json(#"{"detail":"Not Found"}"#, status: 404)
    }
  }

  @Test func everyCreateIsAPostCarryingItsIdempotencyKey() async throws {
    let dive = try KitFixture.text("dive-detail")
    let draft = try KitFixture.text("dive-draft")
    let wire = uuid.uuidString.lowercased()
    let harness = harness([
      "POST dive": .json(dive, status: 201),
      "POST dive-site": .json(try KitFixture.text("dive-site"), status: 201),
      "POST person": .json(try KitFixture.text("people-page").firstItem, status: 201),
      "POST trip": .json(try KitFixture.text("trip"), status: 201),
      "POST course": .json(try KitFixture.text("course"), status: 201),
      "POST contact": .json(try KitFixture.text("contact"), status: 201),
      "POST gear-item": .json(try KitFixture.text("gear-item"), status: 201),
      "POST gear-set": .json(try KitFixture.text("gear-sets-page").firstItem, status: 201),
      "POST dive-draft": .json(draft, status: 201),
      "POST dive-draft/\(wire)/dive": .json(dive, status: 201),
    ])
    let client = harness.client
    _ = try await client.createDive(try self.dive(), idempotencyKey: key)
    _ = try await client.createDiveSite(DiveSiteCreate(name: "Site"), idempotencyKey: key)
    _ = try await client.createPerson(PersonCreate(name: "Person"), idempotencyKey: key)
    _ = try await client.createTrip(TripCreate(name: "Trip"), idempotencyKey: key)
    _ = try await client.createCourse(CourseCreate(name: "Course"), idempotencyKey: key)
    _ = try await client.createContact(ContactCreate(name: "Contact"), idempotencyKey: key)
    _ = try await client.createGearItem(GearItemCreate(name: "Item"), idempotencyKey: key)
    _ = try await client.createGearSet(GearSetCreate(name: "Set"), idempotencyKey: key)
    _ = try await client.createDiveDraft(DiveDraftWrite(), idempotencyKey: key)
    _ = try await client.logDive(fromDraft: uuid, try self.dive(), idempotencyKey: key)

    let requests = harness.transport.requests
    #expect(
      requests.map(\.route) == [
        "POST dive", "POST dive-site", "POST person", "POST trip", "POST course", "POST contact",
        "POST gear-item", "POST gear-set", "POST dive-draft", "POST dive-draft/\(wire)/dive",
      ])
    for request in requests {
      #expect(request.idempotencyKey == key.uuidString.lowercased(), "\(request.route)")
      #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }
    #expect(requests.first?.json == (try JSONValue.parse(KitFixture.data("request-dive-create"))))
  }

  @Test func aCreateRetriedAfterALostReplyIsTheSameRequest() async throws {
    let attempts = Mutex(0)
    let detail = try KitFixture.text("dive-detail")
    let harness = ClientHarness(accessToken: "live") { _ in
      let attempt = attempts.withLock { count in
        count += 1
        return count
      }
      if attempt == 1 { throw URLError(.networkConnectionLost) }
      return .json(detail, status: 201)
    }
    let dive = try self.dive()
    await #expect(throws: APIError.self) {
      try await harness.client.createDive(dive, idempotencyKey: key)
    }
    _ = try await harness.client.createDive(dive, idempotencyKey: key)
    let requests = harness.transport.requests
    #expect(requests.count == 2)
    #expect(requests[0].idempotencyKey == requests[1].idempotencyKey)
    #expect(requests[0].httpBody == requests[1].httpBody)
  }

  @Test func theUpdatesAndTheDeleteAnswerNothingToRead() async throws {
    let wire = uuid.uuidString.lowercased()
    let harness = harness([
      "PATCH dive/\(wire)": Self.message,
      "PATCH gear-set/\(wire)": Self.message,
      "PATCH dive-draft/\(wire)": Self.message,
      "DELETE dive-draft/\(wire)": Self.message,
    ])
    var update = DiveUpdate()
    update.notes = "Edited."
    update.trip = .null
    try await harness.client.updateDive(uuid, update)
    try await harness.client.updateGearSet(uuid, GearSetUpdate(weight: .null))
    try await harness.client.updateDiveDraft(uuid, DiveDraftWrite())
    try await harness.client.deleteDiveDraft(uuid)
    let requests = harness.transport.requests
    #expect(requests.map(\.idempotencyKey) == [nil, nil, nil, nil])
    #expect(
      requests[0].json == (try JSONValue.parse(Data(#"{"notes":"Edited.","trip_uuid":null}"#.utf8)))
    )
    #expect(requests[1].json == (try JSONValue.parse(Data(#"{"weight":null}"#.utf8))))
    #expect(
      requests[2].json
        == (try JSONValue.parse(Data(#"{"gear_set_uuid":null,"values":{}}"#.utf8))))
    #expect(requests[3].httpBody == nil)
  }

  @Test func theDraftsAreRead() async throws {
    let wire = uuid.uuidString.lowercased()
    let harness = harness([
      "GET dive-drafts": .json(try KitFixture.text("dive-drafts-page")),
      "GET dive-draft/\(wire)": .json(try KitFixture.text("dive-draft")),
    ])
    #expect(try await harness.client.diveDrafts(page: 1).data.count == 1)
    #expect(try await harness.client.diveDraft(uuid).values.waterType == "salt")
    #expect(
      harness.transport.requests.first?.url?.query == "page=1&items_per_page=50")
  }

  @Test func aBodyNamingALocalRecordIsNeverSent() async throws {
    let harness = harness([:])
    var dive = try self.dive()
    dive.diveSites.append(.local(UUID()))
    await #expect(throws: LocalRefOnTheWire.self) {
      try await harness.client.createDive(dive, idempotencyKey: key)
    }
    #expect(harness.transport.requests.isEmpty)
  }

  @Test(arguments: [409, 413, 422, 429])
  func aRefusalIsTheStatusAndTheAPIsSentence(status: Int) async throws {
    let body =
      status == 422
      ? try KitFixture.text("error-validation") : #"{"detail":"The server's sentence."}"#
    let harness = ClientHarness(accessToken: "live") { _ in .json(body, status: status) }
    let sentence =
      status == 422 ? "Input should be greater than or equal to 0" : "The server's sentence."
    await #expect(throws: APIError.http(status: status, message: sentence)) {
      try await harness.client.createPerson(PersonCreate(name: "P"), idempotencyKey: key)
    }
  }

  @Test func lookupsSendTheirSearchTheirDateAndTheirNarrowing() async throws {
    let harness = ClientHarness(accessToken: "live") { _ in .emptyPage }
    let until = try #require(DiveTimestamp(wireValue: "2026-09-14T09:12:00+03:00"))
    _ = try await harness.client.lookupDiveSites(
      search: "wall", until: until, uuids: [uuid], page: 2)
    _ = try await harness.client.lookupGearItems(type: "cylinder", page: 1)
    _ = try await harness.client.lookupTrips(page: 1)
    _ = try await harness.client.lookupPeople(search: "", page: 1)
    _ = try await harness.client.lookupCourses(page: 1)
    _ = try await harness.client.lookupContacts(until: until, page: 1)
    _ = try await harness.client.gearSets(page: 1)
    let requests = harness.transport.requests
    #expect(
      requests.map(\.route) == [
        "GET dive-sites/lookup", "GET gear-items/lookup", "GET trips/lookup", "GET people/lookup",
        "GET courses/lookup", "GET contacts/lookup", "GET gear-sets",
      ])
    #expect(
      requests[0].url?.query
        == "page=2&items_per_page=50&search=wall&until=2026-09-14T09:12:00%2B03:00&uuid="
        + uuid.uuidString.lowercased())
    #expect(requests[1].url?.query == "page=1&items_per_page=50&type=cylinder")
    #expect(requests[3].url?.query == "page=1&items_per_page=50")
  }

  @Test func theFormsReads() async throws {
    let harness = harness([
      "GET dives/next-number": .json(try KitFixture.text("dive-number-suggestion")),
      "GET dives/recent-volumes": .json(try KitFixture.text("recent-volumes")),
      "GET user/species/suggest": .json(try KitFixture.text("species-suggest")),
      "POST species/resolve": .json(try KitFixture.text("species")),
      "GET user/storage": .json(try KitFixture.text("storage")),
    ])
    let start = try #require(DiveTimestamp(wireValue: "2026-09-14T09:12:00-04:30"))
    #expect(try await harness.client.nextDiveNumber(startTime: start).diveNumber == 215)
    #expect(try await harness.client.recentVolumes().volumes.count == 3)
    let site = UUID()
    let seen = UUID()
    _ = try await harness.client.speciesSuggest(
      query: "clown", diveSiteUUIDs: [site], excluding: [seen])
    _ = try await harness.client.speciesResolve(aphiaID: 278_400)
    _ = try await harness.client.storage()
    let requests = harness.transport.requests
    #expect(requests[0].url?.query == "start_time=2026-09-14T09:12:00-04:30")
    #expect(requests[1].url?.query == nil)
    #expect(
      requests[2].url?.query
        == "q=clown&dive_site_uuid=\(site.uuidString.lowercased())"
        + "&exclude_species_uuid=\(seen.uuidString.lowercased())")
    #expect(requests[3].json == (try JSONValue.parse(Data(#"{"aphia_id":278400}"#.utf8))))
  }

  @Test func aReverseGeocodeTellsNamelessFromUnknown() async throws {
    let place = try KitFixture.text("geocode-search")
    let answer = Mutex(StubTransport.Response(status: 204))
    let harness = ClientHarness(accessToken: "live") { _ in answer.withLock { $0 } }
    #expect(try await harness.client.geocodeReverse(latitude: 28.5, longitude: 34.5) == .nameless)
    answer.withLock { $0 = .json("null") }
    #expect(try await harness.client.geocodeReverse(latitude: 28.5, longitude: 34.5) == .unknown)
    answer.withLock { $0 = .json(place.firstElement) }
    guard
      case .named(let result) = try await harness.client.geocodeReverse(
        latitude: 28.5, longitude: 34.5)
    else {
      Issue.record("Expected a place")
      return
    }
    #expect(result.name == "Dahab")
    #expect(harness.transport.requests.first?.url?.query == "lat=28.5&lon=34.5")
  }

  @Test func placeSearchAndSiteSuggestions() async throws {
    let harness = harness([
      "GET geocode/search": .json(try KitFixture.text("geocode-search")),
      "GET dive-sites/suggest": .json(try KitFixture.text("dive-site-suggest")),
    ])
    #expect(try await harness.client.geocodeSearch(query: "dahab").count == 1)
    _ = try await harness.client.diveSiteSuggestions(query: "thistle")
    _ = try await harness.client.diveSiteSuggestions(
      query: "thistle", latitude: 27.8, longitude: 33.9)
    let queries = harness.transport.requests.map { $0.url?.query }
    #expect(queries == ["q=dahab", "q=thistle", "q=thistle&latitude=27.8&longitude=33.9"])
  }
}

extension String {
  /// The first object of a page fixture's `data`, as its text.
  fileprivate var firstItem: String {
    let page = try! JSONSerialization.jsonObject(with: Data(utf8)) as! [String: Any]
    let first = (page["data"] as! [Any])[0]
    return String(decoding: try! JSONSerialization.data(withJSONObject: first), as: UTF8.self)
  }

  /// The first element of an array fixture, as its text.
  fileprivate var firstElement: String {
    let first = (try! JSONSerialization.jsonObject(with: Data(utf8)) as! [Any])[0]
    return String(decoding: try! JSONSerialization.data(withJSONObject: first), as: UTF8.self)
  }
}
