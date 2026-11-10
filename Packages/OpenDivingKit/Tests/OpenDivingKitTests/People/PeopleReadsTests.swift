import Foundation
import Synchronization
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// More's *People* and *Contacts* and a person's page as the phone reads them: the kept pages
/// shown offline and read again once a route appears, a queued delete taking the row at once, and
/// a queued edit showing as the pending line.
@MainActor
struct PeopleReadsTests {
  /// A phone whose server answers both lists, the first person's page and their dives, and holds
  /// every write as if there were no route, so what is queued stays queued.
  private func world(diveQueries: Queries? = nil) throws -> OutboxWorld {
    let world = try OutboxWorld()
    let people = try KitFixture.text("people-page")
    let contacts = try KitFixture.text("contacts-page")
    let personRoute = "GET person/" + APIClient.wire(Self.ana)
    let person = OutboxServer.with(try KitFixture.text("person"), uuid: APIClient.wire(Self.ana))
    let dives = try KitFixture.text("dives-page")
    world.server.override { request, _ in
      guard request.route.hasPrefix("GET ") else { throw URLError(.notConnectedToInternet) }
      if request.route == "GET dives" {
        diveQueries?.list.withLock { $0.append(request.url?.query ?? "") }
      }
      return switch request.route {
      case "GET people": .json(people)
      case "GET contacts": .json(contacts)
      case personRoute: .json(person)
      case "GET dives": .json(dives)
      default: nil
      }
    }
    return world
  }

  /// The queries each `GET /dives` was sent with.
  final class Queries: Sendable {
    let list = Mutex<[String]>([])
  }

  /// The first person of `people-page`.
  private static let ana = UUID(uuidString: "01a0e2ed-1be1-7142-996d-0639721e344d")!
  /// The first contact of `contacts-page`.
  private static let bigBlue = UUID(uuidString: "01a0d9e9-bdd0-793a-829f-5dc90613f84f")!

  @Test func bothListsShowOfflineAndReadOnceARouteAppears() async throws {
    let first = try world()
    try await first.load()
    let onlinePeople = PeopleListModel(session: first.session)
    let onlineContacts = ContactListModel(session: first.session)
    await onlinePeople.people.load()
    await onlineContacts.contacts.load()
    #expect(!onlinePeople.people.items.isEmpty)
    #expect(!onlineContacts.contacts.items.isEmpty)

    let route = RouteSwitch()
    let world = try first.relaunched(connectivity: route)
    try await world.session.loadAccount()
    let mark = world.server.mark
    let people = PeopleListModel(session: world.session)
    let showing = Task { await people.show() }
    while !route.isFollowed { await Task.yield() }
    #expect(people.people.items.map(\.uuid) == onlinePeople.people.items.map(\.uuid))
    #expect(people.people.lastUpdated != nil)
    #expect(world.server.count("GET people", since: mark) == 0)
    route.appear()
    while people.people.lastUpdated != nil { await Task.yield() }
    showing.cancel()
    #expect(world.server.count("GET people", since: mark) == 1)

    let contacts = ContactListModel(session: world.session)
    await contacts.contacts.rereadIfStale()
    #expect(contacts.contacts.items.map(\.uuid) == onlineContacts.contacts.items.map(\.uuid))
  }

  @Test func aQueuedDeleteTakesThePersonsRowAtOnce() async throws {
    let world = try world()
    try await world.load()
    let model = PeopleListModel(session: world.session)
    await model.people.load()
    #expect(model.people.items.contains { $0.uuid == Self.ana })
    #expect(PeopleListModel.delete(Self.ana, in: world.outbox()) == nil)
    #expect(!model.people.items.contains { $0.uuid == Self.ana })
  }

  @Test func aQueuedDeleteTakesTheContactsRowAtOnce() async throws {
    let world = try world()
    try await world.load()
    let model = ContactListModel(session: world.session)
    await model.contacts.load()
    #expect(model.contacts.items.contains { $0.uuid == Self.bigBlue })
    #expect(ContactListModel.delete(Self.bigBlue, in: world.outbox()) == nil)
    #expect(!model.contacts.items.contains { $0.uuid == Self.bigBlue })
  }

  @Test func thePageAsksForTheDivesThatNameThem() async throws {
    let queries = Queries()
    let world = try world(diveQueries: queries)
    try await world.load()
    let page = PersonDetailModel(session: world.session, personUUID: Self.ana)
    await page.load()
    #expect(page.page.phase.isLoaded)
    #expect(!page.dives.items.isEmpty)
    let sent = queries.list.withLock { $0 }
    #expect(sent.count == 1)
    #expect(sent.allSatisfy { $0.contains("person_uuid=" + APIClient.wire(Self.ana)) })
  }

  @Test func aQueuedEditShowsAsThePendingLine() async throws {
    let world = try world()
    try await world.load()
    let page = PersonDetailModel(session: world.session, personUUID: Self.ana)
    await page.load()
    #expect(!page.page.hasPendingEdit)
    try world.outbox().queue(.updatePerson(.server(Self.ana), PersonUpdate(notes: "Cave buddy")))
    #expect(page.page.hasPendingEdit)
  }
}
