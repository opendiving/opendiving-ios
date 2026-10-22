import Foundation
import OpenDivingKit
import Testing

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
