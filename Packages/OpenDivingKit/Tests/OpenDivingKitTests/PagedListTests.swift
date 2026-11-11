import Foundation
import Synchronization
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@MainActor
struct PagedListTests {
  /// `GET trips` in three pages of one trip each, named by page, beside the account routes a
  /// refresh reloads.
  private func transport(failPage: Int? = nil) throws -> StubTransport {
    let user = try KitFixture.text("user")
    let people = try KitFixture.text("people-page")
    let trip = try KitFixture.text("trip")
    return StubTransport { request in
      switch request.route {
      case "GET user": return .json(user)
      case "GET people": return .json(people)
      default:
        let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
        let page = Int(query?.first { $0.name == "page" }?.value ?? "1") ?? 1
        if page == failPage { throw URLError(.timedOut) }
        let named = trip.replacingOccurrences(
          of: #""Dahab 2026 (September)""#, with: #""Trip \#(page)""#)
        return .json(
          #"{"data":[\#(named)],"total_count":3,"has_more":\#(page < 3),"page":\#(page),"#
            + #""items_per_page":2}"#)
      }
    }
  }

  private func trips(_ session: Session) -> PagedList<TripRead> {
    PagedList(session: session, itemsPerPage: 2) { client, page, perPage in
      try await client.trips(page: page, itemsPerPage: perPage)
    }
  }

  @Test func appendsPagesWhileThereIsMore() async throws {
    let transport = try transport()
    let list = trips(Session.stub(transport: transport))
    await list.load()
    #expect(list.items.map(\.name) == ["Trip 1"])
    #expect(list.phase == .loaded)
    await list.loadMore()
    await list.loadMore()
    #expect(list.items.map(\.name) == ["Trip 1", "Trip 2", "Trip 3"])
    #expect(!list.hasMore)
    await list.loadMore()
    #expect(transport.requests.count == 3)
    #expect(transport.requests.allSatisfy { $0.url?.query?.contains("items_per_page=2") == true })
  }

  @Test func refreshReloadsTheAccountAndThePeopleThenPageOne() async throws {
    let transport = try transport()
    let session = Session.stub(transport: transport)
    let list = trips(session)
    await list.load()
    await list.loadMore()
    await list.refresh()
    #expect(list.items.map(\.name) == ["Trip 1"])
    #expect(list.hasMore)
    #expect(session.people.count == 3)
    #expect(transport.requests.map(\.route).suffix(3) == ["GET user", "GET people", "GET trips"])
  }

  @Test func aChangeToTheRecordsReloadsEveryPageShownInPlace() async throws {
    let transport = try transport()
    let list = trips(Session.stub(transport: transport))
    await list.load()
    await list.loadMore()
    let before = transport.requests.count

    list.accountListsChanged()
    await list.reloading?.value
    #expect(list.items.map(\.name) == ["Trip 1", "Trip 2"])
    #expect(list.hasMore)
    let pages = transport.requests.dropFirst(before).map { $0.url?.query ?? "" }
    #expect(pages.count == 2)
    #expect(pages.allSatisfy { $0.contains("items_per_page=2") })
    await list.loadMore()
    #expect(list.items.map(\.name) == ["Trip 1", "Trip 2", "Trip 3"])
  }

  @Test func aListLoadedBeforeTheAccountHearsWhatLandsAfterIt() async throws {
    let transport = try transport()
    let session = Session.stub(transport: transport)
    let list = trips(session)
    await list.load()
    #expect(AccountStores.current(session) == nil)

    try await session.loadAccount()
    let stores = try #require(AccountStores.current(session))
    let hub = OutboxHub.hub(for: stores.directory)
    let before = transport.requests.count
    for _ in 0..<100 where list.reloading == nil {
      hub.listsChanged()
      await Task.yield()
    }
    await list.reloading?.value
    #expect(transport.requests.count > before)
  }

  @Test func noLaterPageIsAskedForWhileARefreshWaitsForPageOne() async throws {
    let gate = Gate()
    let transport = GatedTransport(inner: try transport(), gate: gate)
    let list = trips(Session.stub(transport: transport))
    await list.load()
    await list.loadMore()
    #expect(list.items.map(\.name) == ["Trip 1", "Trip 2"])

    transport.arm()
    let refreshing = Task { await list.refresh() }
    await gate.untilArrived()
    let sentBefore = transport.inner.requests.count
    await list.loadMore()
    #expect(transport.inner.requests.count == sentBefore)

    await gate.open()
    await refreshing.value
    #expect(list.items.map(\.name) == ["Trip 1"])
    await list.loadMore()
    #expect(list.items.map(\.name) == ["Trip 1", "Trip 2"])
  }

  @Test func aCancelledLoadIsNoFailureAndTheNextLoadAsksAgain() async throws {
    let session = Session.stub(transport: try transport())
    let calls = Mutex(0)
    let list = PagedList<TripRead>(session: session, itemsPerPage: 2) { client, page, perPage in
      let call = calls.withLock {
        $0 += 1
        return $0
      }
      if call != 2 {
        while !Task.isCancelled { await Task.yield() }
        throw URLError(.cancelled)
      }
      return try await client.trips(page: page, itemsPerPage: perPage)
    }
    let first = Task { await list.load() }
    while calls.withLock({ $0 }) < 1 { await Task.yield() }
    first.cancel()
    await first.value
    #expect(list.phase == .idle)

    await list.load()
    #expect(list.items.map(\.name) == ["Trip 1"])
    let more = Task { await list.loadMore() }
    while calls.withLock({ $0 }) < 3 { await Task.yield() }
    more.cancel()
    await more.value
    #expect(list.pageError == nil)
    #expect(list.items.map(\.name) == ["Trip 1"])
  }

  @Test func aLoadCancelledBehindKeptPagesIsReadAgainWhenTheListIsShownAgain() async throws {
    let first = try OutboxWorld()
    try await first.load()
    await PagedList<DiveListItem>(session: first.session, cache: .dives) { client, page, perPage in
      try await client.dives(page: page, itemsPerPage: perPage)
    }.load()
    let world = try first.relaunched()
    let calls = Mutex(0)
    let list = PagedList<DiveListItem>(session: world.session, cache: .dives) {
      client, page, perPage in
      let call = calls.withLock {
        $0 += 1
        return $0
      }
      if call == 1 {
        while !Task.isCancelled { await Task.yield() }
        throw URLError(.cancelled)
      }
      return try await client.dives(page: page, itemsPerPage: perPage)
    }
    let shown = Task { await list.load() }
    while calls.withLock({ $0 }) < 1 { await Task.yield() }
    shown.cancel()
    await shown.value
    #expect(list.phase == .loaded)
    #expect(list.lastUpdated != nil)

    await list.rereadIfStale()
    #expect(calls.withLock { $0 } == 2)
    #expect(list.lastUpdated == nil)
  }

  @Test func aRefreshCancelledWhileTheAccountReloadsIsNoFailure() async throws {
    let transport = HangingAccount(inner: try transport())
    let list = trips(Session.stub(transport: transport))
    await list.load()
    transport.hangs.withLock { $0 = true }
    let refresh = Task { await list.refresh() }
    while !transport.isHanging { await Task.yield() }
    refresh.cancel()
    await refresh.value
    #expect(list.pageError == nil)
    #expect(list.phase == .loaded)
    #expect(list.items.map(\.name) == ["Trip 1"])
  }

  @Test func aFailedFirstPageIsTheError() async throws {
    let list = trips(Session.stub(transport: try transport(failPage: 1)))
    await list.load()
    guard case .failed(.unreachable) = list.phase else {
      Issue.record("Expected the first page to fail")
      return
    }
  }

  @Test func aFailedLaterPageKeepsWhatIsShown() async throws {
    let list = trips(Session.stub(transport: try transport(failPage: 2)))
    await list.load()
    await list.loadMore()
    #expect(list.items.map(\.name) == ["Trip 1"])
    #expect(list.phase == .loaded)
    #expect(list.pageError != nil)
  }
}

/// Holds the first page-1 request sent after ``arm()`` at the ``Gate``.
private final class GatedTransport: HTTPTransport {
  let inner: StubTransport
  private let gate: Gate
  private let armed = Mutex(false)

  init(inner: StubTransport, gate: Gate) {
    self.inner = inner
    self.gate = gate
  }

  func arm() {
    armed.withLock { $0 = true }
  }

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let isPageOne =
      request.route == "GET trips" && request.url?.query?.contains("page=1&") == true
    let hold =
      isPageOne
      && armed.withLock { armed in
        defer { armed = false }
        return armed
      }
    if hold { await gate.pass() }
    return try await inner.send(request)
  }

  func upload(_ request: URLRequest, fromFile file: URL) async throws -> (Data, HTTPURLResponse) {
    try await inner.upload(request, fromFile: file)
  }
}

/// Holds `GET user` until its task is cancelled once ``hangs`` is set, as a pull's read is
/// cut short.
private final class HangingAccount: HTTPTransport {
  let inner: StubTransport
  let hangs = Mutex(false)
  private let hanging = Mutex(false)

  init(inner: StubTransport) {
    self.inner = inner
  }

  var isHanging: Bool { hanging.withLock { $0 } }

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    if request.route == "GET user", hangs.withLock({ $0 }) {
      hanging.withLock { $0 = true }
      while !Task.isCancelled { await Task.yield() }
      throw URLError(.cancelled)
    }
    return try await inner.send(request)
  }

  func upload(_ request: URLRequest, fromFile file: URL) async throws -> (Data, HTTPURLResponse) {
    try await inner.upload(request, fromFile: file)
  }
}
