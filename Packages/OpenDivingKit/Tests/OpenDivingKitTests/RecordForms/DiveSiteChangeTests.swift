import Foundation
import Testing

@testable import OpenDivingKit

/// A change to a Commons record sends what differs and no more, in the body's own spelling.
@MainActor
struct DiveSiteChangeTests {
  private static let uuid = "01a0a521-28c5-7e34-a572-4d7324f5033b"

  private func record() throws -> DiveSiteRead {
    var object =
      try JSONSerialization.jsonObject(with: Data(KitFixture.text("dive-site").utf8))
      as! [String: Any]
    object["owner"] = DiveSiteOwner.commons
    object["latitude"] = 28.5
    object["longitude"] = 34.5
    object["notes"] = "Mine."
    object["tags"] = ["night"]
    object["depth_from"] = 5
    object["external_ids"] = [["registry": "openstreetmap", "identifier": "node/1"]]
    return try APICoding.decoder().decode(
      DiveSiteRead.self, from: JSONSerialization.data(withJSONObject: object))
  }

  private func members(_ transport: StubTransport) throws -> JSONValue? {
    let body = try #require(transport.requests.last?.httpBody)
    return try JSONValue.parse(body)["members"]
  }

  private func transport(_ answer: StubTransport.Response? = nil) throws -> StubTransport {
    let proposal = try KitFixture.decode(
      PaginatedListResponse<DiveSiteProposalRead>.self, "dive-site-proposals-page"
    ).data.first
    let row = String(decoding: try APICoding.encoder().encode(proposal), as: UTF8.self)
    return StubTransport(routes: [
      "POST dive-site/\(Self.uuid)/proposals": answer ?? .json(row, status: 201)
    ])
  }

  @Test func theFormHoldsNoneOfTheDiversOwnWords() throws {
    let values = DiveSiteFormValues(changing: try record())
    #expect(values.notes.isEmpty)
    #expect(values.tags.isEmpty)
    #expect(!values.isCommons)
  }

  @Test func nothingChangedIsAnEmptyChange() throws {
    let values = DiveSiteFormValues(changing: try record())
    #expect(try values.change(from: values).isEmpty)
  }

  @Test func onlyWhatDiffersIsSentThePinAsAPairThePlaceFlat() async throws {
    let transport = try transport()
    let model = DiveSiteChangeModel(
      session: Session.stub(transport: transport), site: try record())
    model.values.latitude = "28.6"
    model.locationName = "Sharm"
    model.values.depthFrom = nil
    model.values.externalIds = []
    model.ticked = true

    #expect(await model.send())
    let sent = try #require(try members(transport))
    #expect(
      sent.keys.sorted() == [
        "depth_from", "external_ids", "latitude", "location_name", "longitude",
      ])
    #expect(sent["latitude"] == .number(28.6))
    #expect(sent["longitude"] == .number(34.5))
    #expect(sent["location_name"] == .string("Sharm"))
    #expect(sent["depth_from"] == .null)
    #expect(sent["external_ids"] == .array([]))
    let body = try JSONValue.parse(try #require(transport.requests.last?.httpBody))
    #expect(body["attestation"] == .string(CommonsAttestations.change))
  }

  @Test func aBlankPlaceClearsIt() throws {
    let values = DiveSiteFormValues(changing: try record())
    let session = Session.stub(transport: StubTransport(routes: [:]))
    let model = DiveSiteChangeModel(session: session, site: try record())
    model.locationName = "   "
    #expect(model.values.location == nil)
    #expect(try model.values.change(from: values).locationName == .null)
  }

  @Test func aFormWithNothingChangedSaysSoAndSendsNothing() async throws {
    let transport = try transport()
    let model = DiveSiteChangeModel(
      session: Session.stub(transport: transport), site: try record())
    model.ticked = true
    #expect(await !model.send())
    #expect(model.sendError == DiveSiteProposalSummary.changesNothing)
    #expect(transport.requests.isEmpty)
  }

  @Test func clearingThePinIsRefusedBeforeItIsSent() async throws {
    let transport = try transport()
    let model = DiveSiteChangeModel(
      session: Session.stub(transport: transport), site: try record())
    model.values.latitude = ""
    model.values.longitude = ""
    model.ticked = true
    #expect(await !model.send())
    #expect(model.message("latitude") == "A Commons site keeps its pin")
    #expect(transport.requests.isEmpty)
  }

  @Test func nothingIsSentUntilTheTick() async throws {
    let transport = try transport()
    let model = DiveSiteChangeModel(
      session: Session.stub(transport: transport), site: try record())
    model.values.name = "Elsewhere"
    #expect(await !model.send())
    #expect(transport.requests.isEmpty)
  }

  @Test func aRefusalLeavesTheFormAsItWasWithTheServersSentence() async throws {
    let transport = try transport(
      .json(#"{"detail":"a seed keeps the entry it was seeded from"}"#, status: 422))
    let model = DiveSiteChangeModel(
      session: Session.stub(transport: transport), site: try record())
    model.values.externalIds = []
    model.message = "Wrong node."
    model.ticked = true
    #expect(await !model.send())
    #expect(model.sendError == "a seed keeps the entry it was seeded from")
    #expect(model.values.externalIds.isEmpty)
    #expect(model.message == "Wrong node.")
    #expect(model.ticked)
  }
}
