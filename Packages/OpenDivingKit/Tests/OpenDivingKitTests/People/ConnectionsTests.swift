import Foundation
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// *Added you*, the person form it opens, and the pictures a tie shows: the list read and kept, a
/// row's Hide and Disconnect taking it at once, Add making or connecting a person by the account's
/// id, and a picture fetched once per version and drawn only while a read names it.
@MainActor
struct ConnectionsTests {
  private static let robin = UUID(uuidString: "01a0a51f-afe3-7363-a0bc-b0d634c35924")!
  /// The first person of `people-page`, connected, with a picture.
  private static let ana = UUID(uuidString: "01a0e2ed-1be1-7142-996d-0639721e344d")!
  private static let picture = Data([0x52, 0x49, 0x46, 0x46])

  /// A phone whose server answers *Added you* with its fixture, a picture for every avatar route,
  /// and a message for the row's actions.
  private func world() throws -> OutboxWorld {
    let world = try OutboxWorld()
    let page = try KitFixture.text("added-you-page")
    let picture = Self.picture
    world.server.override { request, _ in
      let route = request.route
      if route == "GET people/added-you" { return .json(page) }
      if route.hasSuffix("/avatar") {
        return StubTransport.Response(
          status: 200, headers: ["Content-Type": "image/webp"], body: picture)
      }
      if route.hasSuffix("/hide") { return .json(#"{"message":"Hidden"}"#) }
      if route.hasPrefix("POST people/added-you/") {
        return .json(#"{"message":"Disconnected"}"#)
      }
      return nil
    }
    return world
  }

  @Test func theRowsRoundTripTheirFixture() throws {
    let page = try KitFixture.roundTrip(PaginatedListResponse<AddedYouRow>.self, "added-you-page")
    #expect(page.data.map(\.username) == ["robin", "samr"])
    #expect(ConnectedPicture.of(page.data[0])?.source == .addedYou(Self.robin))
    #expect(ConnectedPicture.of(page.data[1]) == nil)
  }

  @Test func aConnectedPersonReadCarriesThePictureAndAnotherDoesNot() throws {
    let page = try KitFixture.decode(PaginatedListResponse<PersonRead>.self, "people-page")
    let ana = try #require(page.data.first)
    #expect(PersonPageContent.picture(ana)?.source == .person(Self.ana))
    #expect(PersonPageContent.isConnected(ana))
    let dana = try KitFixture.decode(PersonRead.self, "person")
    #expect(PersonPageContent.picture(dana) == nil)
    #expect(!PersonPageContent.isConnected(dana))
    let rows = PersonRowContent.rows(
      [PersonReference(person: .server(Self.ana))], people: [Self.ana: ana])
    #expect(rows.first?.picture == PersonPageContent.picture(ana))
  }

  @Test func hideAndDisconnectEachTakeTheRowOnceTheServerAnswers() async throws {
    let world = try world()
    try await world.load()
    let model = AddedYouModel(session: world.session)
    await model.rows.load()
    #expect(model.shown.map(\.uuid).first == Self.robin)
    let sam = try #require(model.shown.last)

    await model.hide(sam)
    #expect(world.server.routes.contains("POST people/added-you/\(APIClient.wire(sam.uuid))/hide"))
    #expect(!model.shown.contains(sam))

    let robin = try #require(model.shown.first)
    // Dismissed without confirming.
    model.confirmingDisconnect = robin
    model.confirmingDisconnect = nil
    #expect(!world.server.routes.contains { $0.hasSuffix("/disconnect") })
    await model.confirmDisconnect(robin)
    #expect(
      world.server.routes.contains(
        "POST people/added-you/\(APIClient.wire(Self.robin))/disconnect"))
    #expect(model.shown.isEmpty)
  }

  @Test func aRefusedHideKeepsTheRowAndSaysWhy() async throws {
    let world = try world()
    try await world.load()
    let model = AddedYouModel(session: world.session)
    await model.rows.load()
    world.server.override { request, _ in
      request.route.hasSuffix("/hide") ? .status(404, "No such tie.") : nil
    }
    let robin = try #require(model.shown.first)
    await model.hide(robin)
    #expect(model.failure == "No such tie.")
    #expect(model.shown.contains(robin))
  }

  @Test func theFormOpensOnThePersonNamedAsTheAccountIsAndConnectsThem() async throws {
    let world = try world()
    try await world.load()
    let page = try KitFixture.decode(PaginatedListResponse<PersonRead>.self, "people-page")
    let unconnected = try #require(page.data.first { $0.username == nil })
    let account = AddedYouRow(
      uuid: Self.robin, name: " \(unconnected.name.uppercased()) ", username: "robin")
    let model = ConnectPersonModel(session: world.session, account: account)
    #expect(!model.candidates.contains { $0.username != nil })
    #expect(model.choice == .existing(unconnected.uuid))

    let mark = world.server.mark
    #expect(await model.save())
    let write = try #require(world.server.writes(since: mark).first)
    #expect(write.route == "PATCH person/\(APIClient.wire(unconnected.uuid))")
    #expect(write.json as? [String: String] == ["connect_account": APIClient.wire(Self.robin)])
  }

  @Test func aNewPersonIsMadeConnectedUnderTheNameTyped() async throws {
    let world = try world()
    try await world.load()
    let account = AddedYouRow(uuid: Self.robin, name: "Robin Diver", username: "robin")
    let model = ConnectPersonModel(session: world.session, account: account)
    #expect(model.choice == .new)
    #expect(model.values.name == "Robin Diver")
    model.values.name = " "
    #expect(!(await model.save()))
    #expect(model.message("name") == "Name is required")

    model.values.name = "Robin"
    let mark = world.server.mark
    #expect(await model.save())
    let write = try #require(world.server.writes(since: mark).first)
    #expect(write.route == "POST person")
    #expect(write.key != nil)
    #expect(write.json["connect_account"] as? String == APIClient.wire(Self.robin))
    #expect(write.json["name"] as? String == "Robin")
  }

  @Test func aRefusedConnectionIsTheServersSentenceOnTheForm() async throws {
    let world = try world()
    try await world.load()
    world.server.override { request, _ in
      request.route == "POST person" ? .status(422, "That account is not connected to you.") : nil
    }
    let account = AddedYouRow(uuid: Self.robin, name: "Robin Diver", username: "robin")
    let model = ConnectPersonModel(session: world.session, account: account)
    #expect(!(await model.save()))
    #expect(model.failure == "That account is not connected to you.")
  }

  @Test func aPictureIsFetchedOncePerVersionAndDrawsOffline() async throws {
    let first = try world()
    try await first.load()
    let picture = ConnectedPicture(source: .person(Self.ana), version: "ab12")
    #expect(await ConnectedPictures.picture(picture, session: first.session) == Self.picture)
    #expect(first.server.count("GET person/\(APIClient.wire(Self.ana))/avatar") == 1)
    #expect(first.cacheA.connectedPicture(version: "ab12") == Self.picture)

    let world = try first.relaunched(connectivity: RouteSwitch())
    let mark = world.server.mark
    #expect(await ConnectedPictures.picture(picture, session: world.session) == Self.picture)
    let another = ConnectedPicture(source: .addedYou(Self.robin), version: "cd34")
    #expect(await ConnectedPictures.picture(another, session: world.session) == nil)
    #expect(world.server.sent.count == mark)
  }
}
