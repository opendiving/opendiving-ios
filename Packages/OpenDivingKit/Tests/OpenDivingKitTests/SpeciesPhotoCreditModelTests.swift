import Foundation
import OpenDivingKit
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The credit sheet reads the species, and keeps the photo the credit is for.
@MainActor
struct SpeciesPhotoCreditModelTests {
  private let uuid = UUID(uuidString: "01a20000-0000-7000-8000-0000000000c1")!
  private var route: String { "GET species/\(uuid.uuidString.lowercased())" }

  private func transport(species: String) -> StubTransport {
    let route = route
    return StubTransport { request in
      switch StubTransport.routeKey(request) {
      case route: return .json(species)
      case route + "/photo": return StubTransport.Response(body: Data([9, 9]))
      default: return .json(#"{"detail":"Species not found"}"#, status: 404)
      }
    }
  }

  @Test func theCardsOwnPhotoIsKeptWhenItIsTheOneCredited() async throws {
    let transport = transport(species: try KitFixture.text("species"))
    let model = SpeciesPhotoCreditModel(
      session: Session.stub(transport: transport), speciesUUID: uuid, photoVersion: "ab12",
      photo: Data([1]))
    await model.load()

    #expect(model.credit?.text == "Photo by Jane Doe · CC BY-SA 4.0 · Wikimedia Commons")
    #expect(model.photo == Data([1]))
    #expect(transport.requests.map(StubTransport.routeKey) == [route])
  }

  @Test func aPhotoReplacedSinceTheCardWasDrawnIsFetchedAgain() async throws {
    let transport = transport(species: try KitFixture.text("species"))
    let model = SpeciesPhotoCreditModel(
      session: Session.stub(transport: transport), speciesUUID: uuid, photoVersion: "old",
      photo: Data([1]))
    await model.load()

    #expect(model.photo == Data([9, 9]))
    let photo = try #require(transport.requests.last)
    #expect(StubTransport.routeKey(photo) == route + "/photo")
    #expect(photo.url?.query == "v=ab12")
  }

  @Test func aPhotoRemovedSinceIsNoPhotoAndNoCredit() async throws {
    let species = try KitFixture.text("species").replacingOccurrences(
      of: #""photo_sha256": "ab12""#, with: #""photo_sha256": null"#)
    let model = SpeciesPhotoCreditModel(
      session: Session.stub(transport: transport(species: species)), speciesUUID: uuid,
      photoVersion: "ab12", photo: Data([1]))
    await model.load()

    #expect(model.phase.isLoaded)
    #expect(model.photo == nil)
    #expect(model.credit == nil)
  }

  @Test func aSpeciesGoneFromTheCatalogIsNotFound() async throws {
    let model = SpeciesPhotoCreditModel(
      session: Session.stub(transport: transport(species: "")), speciesUUID: UUID(),
      photoVersion: nil, photo: nil)
    await model.load()
    #expect(model.phase == .notFound)
  }
}
