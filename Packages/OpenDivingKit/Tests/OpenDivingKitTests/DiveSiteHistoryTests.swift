import Foundation
import Synchronization
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The site panel's *History*: read for a Commons record where the server edits the Commons,
/// each time the panel opens, and kept nowhere.
@MainActor
struct DiveSiteHistoryTests {
  private static let siteUUID = UUID(uuidString: "01a0a521-28c5-7e34-a572-4d7324f5033b")!
  private static let siteRoute = "GET dive-site/\(APIClient.wire(siteUUID))"
  private static let historyRoute = "GET dive-site/\(APIClient.wire(siteUUID))/history"
  private static let emptyPage = StubTransport.Response.json(
    #"{"data":[],"total_count":0,"has_more":false,"page":1,"items_per_page":100}"#)

  private func record(commons: Bool = true) throws -> String {
    let site = try KitFixture.text("dive-site")
    return commons
      ? site.replacingOccurrences(
        of: #""owner": "account""#, with: #""owner": "opendivingcommons""#)
      : site
  }

  /// A server whose history answers `history` while `failing` is false.
  private func transport(
    primary: Bool = true, commons: Bool = true, history: StubTransport.Response? = nil,
    failing: @escaping @Sendable () -> Bool = { false }
  ) throws -> StubTransport {
    let config = try KitFixture.text("config-commons-primary").replacingOccurrences(
      of: "\"commons_primary\": true", with: "\"commons_primary\": \(primary)")
    let health = try KitFixture.text("health")
    let site = try record(commons: commons)
    let history = try history ?? .json(KitFixture.text("dive-site-history-page"))
    let empty = Self.emptyPage
    let siteRoute = Self.siteRoute
    let historyRoute = Self.historyRoute
    return StubTransport { request in
      switch request.route {
      case "GET config": return .json(config)
      case "GET health": return .json(health)
      case siteRoute: return .json(site)
      case historyRoute:
        return failing() ? .json(#"{"detail":"Try later."}"#, status: 500) : history
      case "GET dives": return empty
      default: return .json(#"{"detail":"Not Found"}"#, status: 404)
      }
    }
  }

  private func historyReads(_ transport: StubTransport) -> Int {
    transport.requests.filter { $0.route == Self.historyRoute }.count
  }

  @Test func aCommonsRecordOnThePrimaryReadsItsHistory() async throws {
    let transport = try transport()
    let model = DiveSiteDetailModel(
      session: Session.stub(transport: transport), siteUUID: Self.siteUUID)
    await model.load()
    #expect(model.history.map { $0.madeBy } == ["Rita Reviewer", "Ann Diver", nil, "Ann Diver"])
  }

  @Test func aRecordWithNoEntryHasNone() async throws {
    let transport = try transport(history: Self.emptyPage)
    let model = DiveSiteDetailModel(
      session: Session.stub(transport: transport), siteUUID: Self.siteUUID)
    await model.load()
    #expect(model.history.isEmpty)
    #expect(historyReads(transport) == 1)
  }

  @Test func aServerThatDoesNotEditTheCommonsIsNotAsked() async throws {
    let transport = try transport(primary: false)
    let model = DiveSiteDetailModel(
      session: Session.stub(transport: transport), siteUUID: Self.siteUUID)
    await model.load()
    #expect(model.history.isEmpty)
    #expect(historyReads(transport) == 0)
  }

  @Test func theDiversOwnSiteIsNotAsked() async throws {
    let transport = try transport(commons: false)
    let model = DiveSiteDetailModel(
      session: Session.stub(transport: transport), siteUUID: Self.siteUUID)
    await model.load()
    #expect(historyReads(transport) == 0)
  }

  @Test func aHistoryReadOnceShowsNothingWhenTheNextOpensReadFails() async throws {
    let failing = Mutex(false)
    let session = Session.stub(transport: try transport { failing.withLock { $0 } })
    let first = DiveSiteDetailModel(session: session, siteUUID: Self.siteUUID)
    await first.load()
    #expect(first.history.count == 4)

    failing.withLock { $0 = true }
    let again = DiveSiteDetailModel(session: session, siteUUID: Self.siteUUID)
    await again.load()
    #expect(again.history.isEmpty)
  }
}
