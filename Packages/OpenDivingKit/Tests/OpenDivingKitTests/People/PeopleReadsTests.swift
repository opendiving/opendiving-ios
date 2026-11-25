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
    while people.people.fetchedAt != nil { await Task.yield() }
    showing.cancel()
    #expect(world.server.count("GET people", since: mark) == 1)

    let contacts = ContactListModel(session: world.session)
    await contacts.contacts.rereadIfStale()
    #expect(contacts.contacts.items.map(\.uuid) == onlineContacts.contacts.items.map(\.uuid))
  }

  /// `GET people` in two pages of three, the second's first person Zoe.
  private func servesTwoPages(_ world: OutboxWorld) throws {
    let first = try KitFixture.text("people-page")
      .replacingOccurrences(of: #""has_more": false"#, with: #""has_more": true"#)
    let second = try KitFixture.text("people-page")
      .replacingOccurrences(of: "01a0e2ed", with: "02a0e2ed")
      .replacingOccurrences(of: "Ana Diaz", with: "Zoe Diaz")
    world.server.override { request, _ in
      guard request.route == "GET people" else { return nil }
      return .json(request.url?.query?.contains("page=2") == true ? second : first)
    }
  }

  @MainActor private final class Shown {
    var list: PagedList<PersonRead>?
  }

  @Test func theKeptPagesStandUntilEveryOneIsReadAgain() async throws {
    let first = try OutboxWorld()
    try servesTwoPages(first)
    try await first.load()
    await PeopleListModel(session: first.session).people.load()

    let world = try first.relaunched()
    try servesTwoPages(world)
    try await world.session.loadAccount()
    let shown = Shown()
    let duringPageTwo = Mutex<Int?>(nil)
    let list = PagedList<PersonRead>(session: world.session, cache: .people, readsEveryPage: true) {
      client, page, perPage in
      if page == 2 {
        let count = await shown.list?.items.count
        duringPageTwo.withLock { $0 = count }
      }
      return try await client.people(page: page, itemsPerPage: perPage)
    }
    shown.list = list
    await list.load()
    #expect(duringPageTwo.withLock { $0 } == 6)
    #expect(list.items.count == 6)
  }

  @Test func theListReadsEveryPageForItsLetters() async throws {
    let world = try OutboxWorld()
    try servesTwoPages(world)
    try await world.load()
    let model = PeopleListModel(session: world.session)
    let showing = Task { await model.show() }
    while model.people.items.count < 6 { await Task.yield() }
    showing.cancel()
    #expect(!model.people.hasMore)
    #expect(model.sections.map(\.letter) == ["A", "B", "C", "Z"])
  }

  @Test func theContactsReadEveryPageForTheirLetters() async throws {
    let world = try OutboxWorld()
    let first = try KitFixture.text("contacts-page")
      .replacingOccurrences(of: #""has_more": false"#, with: #""has_more": true"#)
    let second = try KitFixture.text("contacts-page")
      .replacingOccurrences(of: "01a0d9e9", with: "02a0d9e9")
      .replacingOccurrences(of: "Big Blue Tech", with: "Zenobia Wreck Tours")
    world.server.override { request, _ in
      guard request.route == "GET contacts" else { return nil }
      return .json(request.url?.query?.contains("page=2") == true ? second : first)
    }
    try await world.load()
    let model = ContactListModel(session: world.session)
    let showing = Task { await model.show() }
    while model.contacts.items.count < 4 { await Task.yield() }
    showing.cancel()
    #expect(!model.contacts.hasMore)
    #expect(
      LetterIndex.sections(model.contacts.items) { $0.name }.map(\.letter) == ["B", "E", "Z"])
  }

  @Test func aQueuedDeleteTakesThePersonsRowAtOnce() async throws {
    let world = try world()
    try await world.load()
    let model = PeopleListModel(session: world.session)
    await model.people.load()
    #expect(model.people.items.contains { $0.uuid == Self.ana })
    try world.outbox().queue(.deletePerson(.server(Self.ana)))
    #expect(!model.people.items.contains { $0.uuid == Self.ana })
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
