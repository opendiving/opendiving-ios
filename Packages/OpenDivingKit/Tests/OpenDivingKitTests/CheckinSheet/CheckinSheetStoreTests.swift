import Foundation
import OpenDivingKit
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@MainActor
struct CheckinSheetStoreTests {
  private let server: CheckinSheetServer
  private let origin = ServerOrigin("https://dive.example.org")!

  init() throws {
    server = try CheckinSheetServer()
  }

  private func signedIn() throws -> (Session, StubTransport, CheckinSheetStore) {
    let transport = server.transport()
    let session = Session.stub(origin: origin, transport: transport)
    return (session, transport, CheckinSheetStore(store: session.store, origin: origin))
  }

  /// Everything under the sheet's folder, by relative path.
  private func snapshot(_ session: Session) throws -> [String: Data] {
    let root = session.store.directory(for: origin)
    var files: [String: Data] = [:]
    let paths = FileManager.default.subpaths(atPath: root.path) ?? []
    for path in paths {
      let url = root.appendingPathComponent(path)
      var isDirectory: ObjCBool = false
      _ = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
      if !isDirectory.boolValue { files[path] = try Data(contentsOf: url) }
    }
    return files
  }

  @Test func theFirstRefreshReadsEverythingAndStoresTheBytes() async throws {
    let (session, transport, store) = try signedIn()
    let sheet = try await store.refresh(with: session)

    #expect(
      transport.requests.map(\.route) == [
        "GET user", "GET people", "GET user/checkin-details", "GET user/dive-stats", "GET dives",
        "GET certifications", "GET user/portrait",
        "GET course/01a0a5da-6c85-770b-a009-8c7b4044c060",
        "GET contact/01a0d9e9-bdd0-793a-829f-5dc90613f84f",
        CheckinSheetServer.frontRoute, CheckinSheetServer.backRoute,
      ])
    #expect(transport.requests.allSatisfy { $0.value(forHTTPHeaderField: "If-None-Match") == nil })
    let dives = try #require(transport.requests.first { $0.route == "GET dives" }?.url)
    #expect(dives.query?.contains("items_per_page=1") == true)

    #expect(sheet.name == "Test Diver")
    #expect(sheet.totalDives == 532)
    #expect(sheet.lastDiveStart == DiveTimestamp(wireValue: "2026-10-02T14:19:52.810000+03:00"))
    let first = try #require(sheet.cards.first)
    #expect(first.courseName == "Solo Diver")
    #expect(first.diveCenterName == "Big Blue Tech")
    #expect(first.instructorName == "Ivy Instructor")
    #expect(first.back == nil)
    #expect(
      sheet.cards.map(\.certification.uuid.uuidString).map { $0.lowercased() } == [
        CheckinSheetServer.firstCard, CheckinSheetServer.secondCard,
      ])

    #expect(store.load() == sheet)
    let portrait = try #require(sheet.portrait)
    #expect(store.data(for: portrait) == Data("portrait-1".utf8))
    #expect(store.data(for: try #require(first.front)) == Data("front-1".utf8))
    #expect(store.data(for: try #require(sheet.cards[1].back)) == Data("back-1".utf8))
    #expect(first.front?.name == CheckinSheetServer.frontUUID)
  }

  @Test func aSecondRefreshAsksConditionallyAndKeepsTheBytesOnA304() async throws {
    let (session, transport, store) = try signedIn()
    _ = try await store.refresh(with: session)
    let before = transport.requests.count
    let sheet = try await store.refresh(
      with: session, now: Date(timeIntervalSince1970: 2_000_000_000))

    let second = transport.requests.dropFirst(before)
    let conditional = second.compactMap { $0.value(forHTTPHeaderField: "If-None-Match") }
    #expect(conditional.sorted() == ["\"b1\"", "\"f1\"", "\"p1\""])
    #expect(sheet.updatedAt == Date(timeIntervalSince1970: 2_000_000_000))
    #expect(store.data(for: try #require(sheet.portrait)) == Data("portrait-1".utf8))
    #expect(store.data(for: try #require(sheet.cards[0].front)) == Data("front-1".utf8))
    #expect(store.data(for: try #require(sheet.cards[1].back)) == Data("back-1".utf8))
  }

  @Test func aReplacedPictureIsFetchedAnew() async throws {
    let (session, _, store) = try signedIn()
    _ = try await store.refresh(with: session)
    server.pictures.withLock {
      $0[CheckinSheetServer.frontRoute] = (Data("front-2".utf8), "\"f2\"")
    }
    let sheet = try await store.refresh(with: session)
    let front = try #require(sheet.cards[0].front)
    #expect(front.etag == "\"f2\"")
    #expect(store.data(for: front) == Data("front-2".utf8))
  }

  @Test func aFailedLastSideLeavesTheCachedSheetByteForByte() async throws {
    let (session, _, store) = try signedIn()
    let cached = try await store.refresh(with: session)
    let before = try snapshot(session)
    server.pictures.withLock {
      $0[CheckinSheetServer.frontRoute] = (Data("front-2".utf8), "\"f2\"")
    }
    server.failing.withLock { _ = $0.insert(CheckinSheetServer.backRoute) }

    await #expect(throws: APIError.self) { try await store.refresh(with: session) }
    #expect(try snapshot(session) == before)
    #expect(store.load() == cached)
  }

  @Test func aGoneCourseOrCentreLeavesItsRowOut() async throws {
    let server = server
    let gone = StubTransport { request in
      request.route.hasPrefix("GET course/") || request.route.hasPrefix("GET contact/")
        ? .json(#"{"detail":"Not found"}"#, status: 404)
        : try server.answer(request)
    }
    let session = Session.stub(origin: origin, transport: gone)
    let store = CheckinSheetStore(store: session.store, origin: origin)
    let sheet = try await store.refresh(with: session)
    #expect(sheet.cards[0].courseName == nil)
    #expect(sheet.cards[0].diveCenterName == nil)
    #expect(sheet.cards[0].instructorName == "Ivy Instructor")
  }

  @Test func theSheetSurvivesSignOutAndGoesWithForget() async throws {
    let (session, _, _) = try signedIn()
    let model = CheckinSheetModel(session: session)
    await model.refresh()
    let refreshed = try #require(model.sheet)

    try await session.signOut()
    #expect(session.state == .signingIn(origin))
    #expect(session.user == nil)
    let signedOut = CheckinSheetModel(session: session)
    signedOut.load()
    #expect(signedOut.sheet == refreshed)
    #expect(!signedOut.isSignedIn)
    #expect(signedOut.content?.diving[1] == Figure(label: "Max depth", value: "47.42 m"))

    try session.forget(origin)
    let forgotten = CheckinSheetModel(session: session)
    forgotten.load()
    #expect(forgotten.sheet == nil)
    #expect(!session.hasState(origin))
  }

  @Test func signedOutTheModelAsksNothing() async throws {
    let (session, transport, _) = try signedIn()
    try await session.signOut()
    let before = transport.requests.count
    let model = CheckinSheetModel(session: session)
    await model.refresh()
    #expect(transport.requests.count == before)
    #expect(model.refreshError == nil)
  }

  @Test func aFailedRefreshKeepsTheSheetAndSaysWhy() async throws {
    let (session, _, _) = try signedIn()
    let model = CheckinSheetModel(session: session)
    await model.refresh()
    let cached = try #require(model.sheet)
    server.failing.withLock { _ = $0.insert("GET user/dive-stats") }

    await model.refresh()
    #expect(model.sheet == cached)
    #expect(model.refreshError != nil)
    #expect(!model.isRefreshing)
  }
}
