import Foundation
import OpenDivingKit
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@MainActor
struct DiveDetailModelTests {
  private let diveID = UUID(uuidString: "01a20000-0000-7000-8000-000000000001")!
  private let tripID = "01a0a57a-92c3-73d0-8f2c-e200878f9878"
  private let courseID = "01a0a5da-6c85-770b-a009-8c7b4044c060"
  private let contactID = "01a0d9e9-bdd0-793a-829f-5dc90613f84f"

  /// The two-recording dive linked to a trip, a course and a dive centre.
  private func linkedDive() throws -> String {
    var object =
      try JSONSerialization.jsonObject(with: KitFixture.data("dive-two-recordings"))
      as? [String: Any] ?? [:]
    object["trip_uuid"] = tripID
    object["course_uuid"] = courseID
    object["contact_uuid"] = contactID
    return String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
  }

  private func session(_ routes: [String: StubTransport.Response]) -> (Session, StubTransport) {
    let transport = StubTransport(routes: routes)
    return (Session.stub(transport: transport), transport)
  }

  @Test func loadsTheDiveAndWhatItNames() async throws {
    let (session, _) = session([
      "GET dive/\(diveID.uuidString.lowercased())": .json(try linkedDive()),
      "GET dive/\(diveID.uuidString.lowercased())/neighbors": .json(
        try KitFixture.text("dive-neighbors")),
      "GET trip/\(tripID)": .json(try KitFixture.text("trip")),
      "GET course/\(courseID)": .json(try KitFixture.text("course")),
      "GET contact/\(contactID)": .json(try KitFixture.text("contact")),
    ])
    let model = DiveDetailModel(session: session, diveUUID: diveID)
    await model.load()

    let content = try #require(model.content)
    #expect(content.navigationTitle == "#212")
    #expect(content.course == "Solo Diver")
    #expect(content.location?.trip?.name == "Dahab 2026 (September)")
    #expect(content.location?.diveCenter?.name == "Big Blue Tech")
    #expect(model.neighbors?.previous?.diveNumber == 531)
    #expect(model.neighbors?.next == nil)
  }

  @Test func aLinkThatFailsToResolveLeavesThePageUp() async throws {
    let (session, _) = session([
      "GET dive/\(diveID.uuidString.lowercased())": .json(try linkedDive())
    ])
    let model = DiveDetailModel(session: session, diveUUID: diveID)
    await model.load()

    let content = try #require(model.content)
    #expect(content.course == nil)
    #expect(content.location?.trip == nil)
    #expect(content.location?.diveCenter == nil)
    #expect(model.neighbors == nil)
  }

  @Test func aMissingDiveFailsWithTheAPIsMessage() async throws {
    let (session, _) = session([
      "GET dive/\(diveID.uuidString.lowercased())": .json(
        #"{"detail":"Dive not found"}"#, status: 404)
    ])
    let model = DiveDetailModel(session: session, diveUUID: diveID)
    await model.load()

    #expect(model.phase == .failed(.http(status: 404, message: "Dive not found")))
    #expect(model.content == nil)
  }

  @Test func aDiveWithNoLinksAsksForNone() async throws {
    let other = UUID(uuidString: "9c890a72-f1cb-5eef-ae82-3ed803b61f17")!
    let (session, transport) = session([
      "GET dive/\(other.uuidString.lowercased())": .json(try KitFixture.text("dive-detail"))
    ])
    let model = DiveDetailModel(session: session, diveUUID: other)
    await model.load()

    #expect(model.content != nil)
    #expect(
      transport.requests.map(StubTransport.routeKey) == [
        "GET dive/\(other.uuidString.lowercased())",
        "GET dive/\(other.uuidString.lowercased())/neighbors",
      ])
  }

  @Test func fetchesASpeciesPhotoByItsVersion() async throws {
    let (session, transport) = session([
      "GET species/01a20000-0000-7000-8000-0000000000c1/photo": StubTransport.Response(
        body: Data([1, 2, 3]))
    ])
    let model = DiveDetailModel(session: session, diveUUID: diveID)
    let photo = await model.speciesPhoto(
      UUID(uuidString: "01a20000-0000-7000-8000-0000000000c1")!, version: "ab12")
    #expect(photo == Data([1, 2, 3]))
    let query = transport.requests.last?.url?.query
    #expect(query == "v=ab12")
  }

  @Test func stepsToANeighbourInPlace() async throws {
    let other = UUID(uuidString: "9c890a72-f1cb-5eef-ae82-3ed803b61f17")!
    let (session, _) = session([
      "GET dive/\(diveID.uuidString.lowercased())": .json(
        try KitFixture.text("dive-two-recordings")),
      "GET dive/\(other.uuidString.lowercased())": .json(try KitFixture.text("dive-detail")),
    ])
    let model = DiveDetailModel(session: session, diveUUID: diveID)
    await model.load()
    #expect(model.content?.navigationTitle == "#212")

    await model.show(other)
    #expect(model.diveUUID == other)
    #expect(model.content?.navigationTitle == "#532")
    #expect(!model.isStepping)
  }
}
