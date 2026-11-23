import Foundation
import Synchronization
import Testing

@testable import OpenDivingKit

/// What a list leaves out of the records the server said it no longer has, and when it shows one
/// again: once a page fetched since names it, imported again under its uuid.
@MainActor
struct GoneRecordsTests {
  /// The rows a list's fetch answers, as the test sets them; nil fails the fetch, so the list
  /// keeps the pages it has.
  final class Pages<Item: Codable & Sendable>: Sendable {
    private let rows: Mutex<[Item]?>

    init(_ rows: [Item]) { self.rows = Mutex(rows) }

    func answer(_ rows: [Item]?) { self.rows.withLock { $0 = rows } }

    func fetch() throws -> PaginatedListResponse<Item> {
      guard let rows = rows.withLock({ $0 }) else { throw URLError(.badServerResponse) }
      return PaginatedListResponse(
        data: rows, totalCount: rows.count, hasMore: false, page: 1, itemsPerPage: 100)
    }
  }

  private func dives() throws -> [DiveListItem] {
    try KitFixture.decode(PaginatedListResponse<DiveListItem>.self, "dives-page").data
  }

  private func list(_ world: OutboxWorld, _ pages: Pages<DiveListItem>) -> PagedList<DiveListItem> {
    PagedList(session: world.session, cache: .dives) { _, _, _ in try pages.fetch() }
  }

  @Test func aDeletedDiveIsLeftOutUntilAPageFetchedSinceNamesIt() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let rows = try dives()
    let dive = try #require(rows.first).id
    let before = Pages(rows)
    let since = Pages(rows)
    let held = list(world, before)
    let read = list(world, since)
    await held.load()
    await read.load()

    // `held` reads nothing more, so what it shows is the page it fetched before the delete.
    before.answer(nil)
    since.answer(rows.filter { $0.id != dive })
    let outbox = world.outbox()
    try outbox.queue(.deleteDive(.server(dive)))
    await outbox.settled()
    await held.reloading?.value
    await read.reloading?.value
    #expect(!held.items.map(\.id).contains(dive))
    #expect(!read.items.map(\.id).contains(dive))

    // Imported again under its uuid.
    since.answer(rows)
    await read.refresh()
    #expect(read.items.map(\.id).contains(dive))
    #expect(held.items.map(\.id).contains(dive))
  }

  @Test func aCertificationAnswered404IsLeftOutUntilAPageFetchedSinceNamesIt() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let certification = try KitFixture.decode(CertificationRead.self, "certification-front-only")
    let before = Pages([certification])
    let since = Pages([certification])
    let held = PagedList<CertificationRead>(session: world.session, cache: .certifications) {
      _, _, _ in try before.fetch()
    }
    let read = PagedList<CertificationRead>(session: world.session, cache: .certifications) {
      _, _, _ in try since.fetch()
    }
    await held.load()
    await read.load()

    before.answer(nil)
    since.answer([])
    let stores = try #require(AccountStores.current(world.session))
    stores.forgetRecord(.certification, certification.uuid)
    await held.reloading?.value
    await read.reloading?.value
    #expect(held.items.isEmpty)
    #expect(read.items.isEmpty)

    since.answer([certification])
    await read.refresh()
    #expect(read.items.map(\.uuid) == [certification.uuid])
    #expect(held.items.map(\.uuid) == [certification.uuid])
  }

  @Test func aDeletedRecordNoPageSinceNamesStaysHidden() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let rows = try dives()
    let dive = try #require(rows.first).id
    let before = Pages(rows)
    let since = Pages(rows)
    let held = list(world, before)
    let read = list(world, since)
    await held.load()
    await read.load()

    before.answer(nil)
    since.answer(rows.filter { $0.id != dive })
    let outbox = world.outbox()
    try outbox.queue(.deleteDive(.server(dive)))
    await outbox.settled()
    await read.refresh()
    await held.refresh()
    #expect(!held.items.map(\.id).contains(dive))
    #expect(!read.items.map(\.id).contains(dive))
  }

  @Test func aQueuedDeleteHidesItsRowWhateverAPageSays() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let rows = try dives()
    let dive = try #require(rows.first).id
    world.offline()
    let outbox = world.outbox()
    let item = try outbox.queue(.deleteDive(.server(dive)))

    let list = list(world, Pages(rows))
    await list.load()
    #expect(list.phase == .loaded)
    #expect(!list.items.map(\.id).contains(dive))

    outbox.discard(item.id)
    #expect(list.items.map(\.id).contains(dive))
    await outbox.settled()
  }

  @Test func onlyAPageWhoseFetchBeganAfterTheGoingTakesARecordBack() {
    let hub = OutboxHub.hub(for: URL(fileURLWithPath: "/gone-records-\(UUID().uuidString)"))
    let record = UUID()
    let before = Date().addingTimeInterval(-1)
    hub.gone(record)

    hub.named([record], fetchedSince: before)
    #expect(hub.deleted[record] != nil)
    hub.named([UUID()], fetchedSince: Date())
    #expect(hub.deleted[record] != nil)
    hub.named([record], fetchedSince: Date())
    #expect(hub.deleted[record] == nil)
  }
}
