import Foundation
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A form choosing public waits for its site's writes: until they land and the server's record is
/// read, or until a pass has said it will not be today.
@MainActor
struct DiveSiteLandingTests {
  private static let uuid = UUID(uuidString: "01a0a521-28c5-7e34-a572-4d7324f5033b")!
  private static var route: String { "GET dive-site/\(APIClient.wire(uuid))" }

  private func newSite(_ outbox: OutboxModel) -> RecordSheetModel<DiveSiteFormValues> {
    RecordSheetModel(
      outbox: outbox, values: DiveSiteFormValues(name: "Canyon", latitude: "28", longitude: "34"))
  }

  private func edit(_ outbox: OutboxModel, name: String) -> RecordSheetModel<DiveSiteFormValues> {
    let sheet = RecordSheetModel(
      outbox: outbox, editing: .server(Self.uuid), read: DiveSiteFormValues(name: "Tiger Reef"))
    sheet.values.name = name
    return sheet
  }

  /// Every read of a site answers it, under the uuid asked for.
  private func answerReads(_ world: OutboxWorld, then write: StubTransport.Response? = nil) throws {
    let site = try KitFixture.text("dive-site")
    world.server.override { request, _ in
      let route = request.route
      if route.hasPrefix("GET dive-site/") {
        let uuid = String(route.split(separator: "/").last!)
        return .json(OutboxServer.with(site, uuid: uuid))
      }
      return route.hasPrefix("GET ") ? nil : write
    }
  }

  @Test func aCreateLandsAndTheServersRecordIsRead() async throws {
    let world = try OutboxWorld()
    let outbox = world.outbox()
    try await world.load(outbox)
    try answerReads(world)
    let sheet = newSite(outbox)

    let ref = try #require(sheet.save())
    #expect(ref.isLocal)
    let landing = await sheet.landing(of: ref)
    let created = try #require(world.server.created.first)
    guard case .landed(let site) = landing else {
      Issue.record("kept: \(landing)")
      return
    }
    #expect(site.uuid == created)
    await outbox.settled()
  }

  @Test func anEditLandsAndIsReadAfterIt() async throws {
    let world = try OutboxWorld()
    let outbox = world.outbox()
    try await world.load(outbox)
    try answerReads(world)
    let sheet = edit(outbox, name: "Canyon")
    let ref = try #require(sheet.save())
    let mark = world.server.mark

    let landing = await sheet.landing(of: ref)
    guard case .landed(let site) = landing else {
      Issue.record("kept: \(landing)")
      return
    }
    #expect(site.uuid == Self.uuid)
    #expect(outbox.items.isEmpty)
    #expect(world.server.count(Self.route, since: mark) == 1)
    let patch = world.server.routes.firstIndex { $0.hasPrefix("PATCH dive-site/") }
    let read = world.server.routes.firstIndex { $0 == Self.route }
    #expect(try #require(patch) < (try #require(read)))
  }

  @Test func aSaveThatQueuesNothingOpensOnAFreshRead() async throws {
    let world = try OutboxWorld()
    let outbox = world.outbox()
    try await world.load(outbox)
    try answerReads(world)
    let sheet = edit(outbox, name: "Tiger Reef")
    let ref = try #require(sheet.save())
    #expect(outbox.items.isEmpty)
    guard case .landed = await sheet.landing(of: ref) else {
      Issue.record("kept")
      return
    }
    #expect(world.server.count(Self.route) == 1)
  }

  @Test func aSaveThatQueuesNothingWaitsForAnEarlierWriteOfTheSite() async throws {
    let world = try OutboxWorld()
    let outbox = world.outbox()
    try await world.load(outbox)
    world.offline()
    let first = edit(outbox, name: "Canyon")
    _ = try #require(first.save())
    await outbox.settled()
    #expect(outbox.items.count == 1)

    try answerReads(world)
    let second = RecordSheetModel(
      outbox: outbox, editing: .server(Self.uuid), read: DiveSiteFormValues(name: "Tiger Reef"))
    let ref = try #require(second.save())
    #expect(outbox.items.count == 1)
    guard case .landed = await second.landing(of: ref) else {
      Issue.record("kept")
      return
    }
    #expect(world.server.count("PATCH dive-site/\(APIClient.wire(Self.uuid))") >= 1)
    #expect(outbox.items.isEmpty)
  }

  @Test func withNoRouteTheFormDoesNotWait() async throws {
    let route = SwitchedRoute()
    let world = try OutboxWorld(connectivity: route)
    let outbox = world.outbox()
    try await world.load(outbox)
    route.isRouteAvailable = false
    let sheet = newSite(outbox)
    let ref = try #require(sheet.save())
    let mark = world.server.mark

    #expect(await sheet.landing(of: ref) == .kept(ref))
    #expect(world.server.writes(since: mark).isEmpty)
    #expect(outbox.items.count == 1)
  }

  @Test func aRefusalPendingHoldsIsKept() async throws {
    let world = try OutboxWorld()
    let outbox = world.outbox()
    try await world.load(outbox)
    try answerReads(world, then: .status(422, "A site needs a name."))
    let sheet = newSite(outbox)
    let ref = try #require(sheet.save())

    #expect(await sheet.landing(of: ref) == .kept(ref))
    await outbox.settled()
    #expect(outbox.items.first?.isFailed == true)
  }

  @Test(arguments: [429, 503])
  func anAnswerTheOutboxRetriesLaterIsKeptOnceThePassEnds(status: Int) async throws {
    let world = try OutboxWorld()
    let outbox = world.outbox()
    try await world.load(outbox)
    try answerReads(world, then: .status(status))
    let sheet = newSite(outbox)
    let ref = try #require(sheet.save())

    #expect(await sheet.landing(of: ref) == .kept(ref))
    await outbox.settled()
    #expect(outbox.items.first?.isPending == true)
  }

  @Test func aServerThatDoesNotAnswerIsKept() async throws {
    let world = try OutboxWorld()
    let outbox = world.outbox()
    try await world.load(outbox)
    world.offline()
    let sheet = newSite(outbox)
    let ref = try #require(sheet.save())
    #expect(await sheet.landing(of: ref) == .kept(ref))
    await outbox.settled()
  }

  @Test func aFreshReadThatFailsIsKept() async throws {
    let world = try OutboxWorld()
    let outbox = world.outbox()
    try await world.load(outbox)
    let route = Self.route
    world.server.override { request, _ in
      request.route == route ? .status(500) : nil
    }
    let sheet = edit(outbox, name: "Tiger Reef")
    let ref = try #require(sheet.save())
    #expect(await sheet.landing(of: ref) == .kept(ref))
  }

  @Test func theSwapPutsTheRecordWhereTheSiteStoodAndNamesItOnce() async throws {
    let world = try OutboxWorld()
    let outbox = world.outbox()
    try await world.load(outbox)
    world.offline()
    let form = DiveFormModel(session: world.session, mode: .create)
    let record = try APICoding.decoder().decode(
      DiveSiteRead.self,
      from: Data(
        KitFixture.text("dive-site")
          .replacingOccurrences(of: #""owner": "account""#, with: #""owner": "opendivingcommons""#)
          .replacingOccurrences(
            of: APIClient.wire(Self.uuid), with: "01a14b2e-0c3d-7a10-9f00-4b2b3c4d5e6f"
          ).utf8))
    let first = RecordRef.server(UUID())
    let created = try #require(
      try outbox.queue(.createDiveSite(DiveSiteCreate(name: "Canyon"))).creates)
    let retired = RecordRef.server(Self.uuid)
    let last = RecordRef.server(UUID())

    form.change { $0.diveSites = [first, created, last] }
    form.swapSite([created, retired], for: record)
    let ref = RecordRef.server(record.uuid)
    #expect(form.values.diveSites == [first, ref, last])
    #expect(form.row(ref, .diveSites).title == record.name)

    form.change { $0.diveSites = [retired, first, ref] }
    form.swapSite([created, retired], for: record)
    #expect(form.values.diveSites == [first, ref])

    form.change { $0.diveSites = [first] }
    form.swapSite([created, retired], for: record)
    #expect(form.values.diveSites == [first])
    await form.settled()
  }
}
