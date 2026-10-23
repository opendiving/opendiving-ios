import Foundation
import OpenDivingKit
import Synchronization
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The trip's and the site's pages read their record, then its dives and what its cards
/// name.
@MainActor
struct DetailModelTests {
  private let tripUUID = UUID(uuidString: "01a0a57a-92c3-73d0-8f2c-e200878f9878")!
  private let siteUUID = UUID(uuidString: "01a0a521-28c5-7e34-a572-4d7324f5033b")!
  private let centre = "01a0d9e9-bdd0-793a-829f-5dc90613f84f"

  private func query(_ request: URLRequest, _ name: String) -> String? {
    URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
      .queryItems?.first { $0.name == name }?.value
  }

  @Test func aTripReadsItsOwnDivesAHundredAtATimeAndItsContacts() async throws {
    let trip = try JSONSerialization.data(
      withJSONObject: {
        var object = try JSONSerialization.jsonObject(with: KitFixture.data("trip"))
          as! [String: Any]
        object["contact_uuids"] = [centre, "01a0e2ed-0000-7000-8000-0000000000ff"]
        return object
      }())
    let dives = try KitFixture.text("dives-page")
    let contact = try KitFixture.text("contact")
    let transport = StubTransport { request in
      switch StubTransport.routeKey(request) {
      case "GET trip/\(tripUUID.uuidString.lowercased())":
        return StubTransport.Response(
          headers: ["Content-Type": "application/json"], body: trip)
      case "GET dives": return .json(dives)
      case "GET contact/\(centre)": return .json(contact)
      default: return .json(#"{"detail":"Not Found"}"#, status: 404)
      }
    }
    let model = TripDetailModel(session: Session.stub(transport: transport), tripUUID: tripUUID)
    await model.load()

    guard case .loaded(let loaded) = model.phase else {
      Issue.record("not loaded: \(model.phase)")
      return
    }
    #expect(loaded.name == "Dahab 2026 (September)")
    #expect(model.dives.items.count == 1)
    #expect(TripSummary.diveCenters(loaded, contacts: model.contacts) == "Big Blue Tech")
    let list = try #require(
      transport.requests.first { StubTransport.routeKey($0) == "GET dives" })
    #expect(query(list, "trip_uuid") == tripUUID.uuidString.lowercased())
    #expect(query(list, "items_per_page") == "100")
  }

  @Test func aMissingTripIsNotFoundAndAFailureIsRetried() async throws {
    let fails = Mutex(true)
    let trip = try KitFixture.text("trip")
    let transport = StubTransport { request in
      switch StubTransport.routeKey(request) {
      case "GET trip/\(tripUUID.uuidString.lowercased())":
        if fails.withLock({ $0 }) { throw URLError(.timedOut) }
        return .json(trip)
      case "GET dives":
        return .json(#"{"data":[],"total_count":0,"has_more":false,"page":1,"items_per_page":100}"#)
      default: return .json(#"{"detail":"Not Found"}"#, status: 404)
      }
    }
    let model = TripDetailModel(session: Session.stub(transport: transport), tripUUID: tripUUID)
    await model.load()
    guard case .failed = model.phase else {
      Issue.record("expected a failure: \(model.phase)")
      return
    }
    fails.withLock { $0 = false }
    await model.load()
    #expect(model.phase.isLoaded)

    let gone = TripDetailModel(session: Session.stub(transport: transport), tripUUID: UUID())
    await gone.load()
    #expect(gone.phase == .notFound)
  }

  @Test func aSiteReadsItsDivesAndItsSpeciesWithTheirPhotos() async throws {
    let site = try KitFixture.text("dive-site").replacingOccurrences(
      of: #""species_count": 0"#, with: #""species_count": 2"#)
    let dives = try KitFixture.text("dives-page")
    let species = try KitFixture.text("species-life-list")
    let transport = StubTransport { request in
      let route = StubTransport.routeKey(request)
      switch route {
      case "GET dive-site/\(siteUUID.uuidString.lowercased())": return .json(site)
      case "GET dives": return .json(dives)
      case "GET user/species": return .json(species)
      default:
        if route.hasSuffix("/photo") { return StubTransport.Response(body: Data([1, 2, 3])) }
        return .json(#"{"detail":"Not Found"}"#, status: 404)
      }
    }
    let model = DiveSiteDetailModel(
      session: Session.stub(transport: transport), siteUUID: siteUUID)
    await model.load()

    #expect(model.phase.isLoaded)
    #expect(model.dives.items.count == 1)
    guard case .loaded(let entries) = model.species else {
      Issue.record("species not loaded: \(model.species)")
      return
    }
    #expect(entries.count == 2)
    let list = try #require(
      transport.requests.first { StubTransport.routeKey($0) == "GET dives" })
    #expect(query(list, "dive_site_uuid") == siteUUID.uuidString.lowercased())
    #expect(
      query(
        try #require(transport.requests.first { StubTransport.routeKey($0) == "GET user/species" }),
        "dive_site_uuid") == siteUUID.uuidString.lowercased())

    for entry in entries {
      await model.loadPhoto(entry)
      await model.loadPhoto(entry)
    }
    #expect(model.photos[entries[0].uuid] == Data([1, 2, 3]))
    #expect(model.photos[entries[1].uuid] == nil)
    // Once for the one species with a photo, however often its card asks.
    #expect(transport.requests.filter { $0.url?.path.hasSuffix("/photo") == true }.count == 1)
  }

  @Test func aSiteWithNoSpeciesAsksForNone() async throws {
    let site = try KitFixture.text("dive-site")
    let transport = StubTransport { request in
      switch StubTransport.routeKey(request) {
      case "GET dive-site/\(siteUUID.uuidString.lowercased())": return .json(site)
      case "GET dives":
        return .json(#"{"data":[],"total_count":0,"has_more":false,"page":1,"items_per_page":100}"#)
      default: return .json(#"{"detail":"Not Found"}"#, status: 404)
      }
    }
    let model = DiveSiteDetailModel(
      session: Session.stub(transport: transport), siteUUID: siteUUID)
    await model.load()
    #expect(model.species == .none)
    #expect(!transport.requests.contains { StubTransport.routeKey($0) == "GET user/species" })
  }
}
