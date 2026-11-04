import Foundation
import OpenDivingKit
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A form's map draws the instance's style only where it draws tiles and names their credit, and
/// keeps what it was given for the next launch, per theme and language.
@MainActor
struct MapStyleModelTests {
  private static let origin = ServerOrigin("https://dive.example.org")!
  private static let credit = "[OpenFreeMap](https://openfreemap.org/)"
  private nonisolated static let style = #"{"version":8,"name":"Liberty"}"#

  private let support = FileManager.default.temporaryDirectory
    .appendingPathComponent("MapStyleModelTests-\(UUID().uuidString)", isDirectory: true)

  private func session(_ transport: any HTTPTransport) -> Session {
    Session(
      transport: transport,
      secrets: InMemorySecretStore([Self.origin.description: "refresh"]),
      activeOrigin: InMemoryActiveOriginStore(Self.origin), background: NoBackgroundExecution(),
      applicationSupport: support,
      userAgent: UserAgent(appVersion: "0", systemVersion: "0", model: "iPhone"),
      accessToken: "access")
  }

  private static func config(tiles: Bool, credit: String?) -> StubTransport.Response {
    let attribution = credit.map { #""\#($0)""# } ?? "null"
    return .json(
      #"{"registration_mode":"invite","project_operated":true,"map_tiles":\#(tiles),"#
        + #""map_attribution":\#(attribution)}"#)
  }

  private nonisolated static func served(_ style: String = style, etag: String = #""v1""#)
    -> StubTransport.Response
  {
    StubTransport.Response(
      headers: ["Content-Type": "application/json", "ETag": etag], body: Data(style.utf8))
  }

  private static func transport(
    config: StubTransport.Response = config(tiles: true, credit: credit),
    style: @escaping @Sendable (URLRequest) throws -> StubTransport.Response = { _ in served() }
  ) -> StubTransport {
    StubTransport { request in
      let route = StubTransport.routeKey(request)
      if route == "GET config" { return config }
      if route == "GET health" { return .json(#"{"version":"1","commit":"x"}"#) }
      if route.hasPrefix("GET map-style/") { return try style(request) }
      return .json(#"{"detail":"Not Found"}"#, status: 404)
    }
  }

  private func styleRequests(_ transport: StubTransport) -> [URLRequest] {
    transport.requests.filter { StubTransport.routeKey($0).hasPrefix("GET map-style/") }
  }

  private func heldStyles(_ session: Session) -> [String] {
    let directory = session.store.directory(for: Self.origin)
      .appendingPathComponent("MapTiles", isDirectory: true)
    let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    return names.filter { $0.hasPrefix("style-") && $0.hasSuffix(".json") }
  }

  @Test func asksForTheThemesStyleWithTheBearerAndShowsItWithTheCredit() async throws {
    let transport = Self.transport()
    let model = MapStyleModel(session: session(transport))
    #expect(!model.hasMap)
    await model.show(.dark)

    #expect(model.shown == MapStyleModel.Shown(styleJSON: Self.style, credit: Self.credit))
    #expect(model.hasMap)
    let request = try #require(styleRequests(transport).first)
    #expect(StubTransport.routeKey(request) == "GET map-style/dark")
    #expect(request.bearer == "access")
    #expect(request.value(forHTTPHeaderField: "If-None-Match") == nil)
  }

  @Test func theStyleIsAskedForInTheReadersLanguageAndHeldPerLanguage() async throws {
    let transport = Self.transport()
    let session = session(transport)
    let client = try session.requireClient()
    let directory = session.store.directory(for: Self.origin)
      .appendingPathComponent("MapTiles", isDirectory: true)
    let german = MapTileStore(client: client, directory: directory, language: "de-DE")
    let french = MapTileStore(client: client, directory: directory, language: "fr")
    #expect(await german.fetchStyle(.light) == Self.style)
    #expect(await german.style(.light) == Self.style)
    #expect(await french.style(.light) == nil)
    #expect(heldStyles(session) == ["style-light-de-DE.json"])
    let url = try #require(styleRequests(transport).first?.url)
    #expect(url.query == "language=de-DE")
  }

  @Test func anInstanceThatDrawsNoTilesIsAskedForNoStyle() async {
    let transport = Self.transport(config: Self.config(tiles: false, credit: nil))
    let model = MapStyleModel(session: session(transport))
    await model.show(.light)
    #expect(model.shown == nil)
    #expect(styleRequests(transport).isEmpty)
  }

  @Test func anInstanceThatNamesNoCreditIsAskedForNoStyle() async {
    let transport = Self.transport(config: Self.config(tiles: true, credit: nil))
    let model = MapStyleModel(session: session(transport))
    await model.show(.light)
    #expect(model.shown == nil)
    #expect(styleRequests(transport).isEmpty)
  }

  @Test func aHeldStyleAndCreditShowOfflineWithNoAnswerAtAll() async {
    await MapStyleModel(session: session(Self.transport())).show(.light)

    let offline = StubTransport { _ in throw URLError(.notConnectedToInternet) }
    let model = MapStyleModel(session: session(offline))
    await model.show(.light)
    #expect(model.shown == MapStyleModel.Shown(styleJSON: Self.style, credit: Self.credit))
  }

  @Test func aHeldStyleOfAnotherThemeShowsNothing() async {
    await MapStyleModel(session: session(Self.transport())).show(.light)

    let offline = StubTransport { _ in throw URLError(.notConnectedToInternet) }
    let model = MapStyleModel(session: session(offline))
    await model.show(.dark)
    #expect(model.shown == nil)
  }

  @Test func anInstanceThatStoppedDrawingTilesTakesDownWhatThePhoneHolds() async {
    await MapStyleModel(session: session(Self.transport())).show(.light)

    let model = MapStyleModel(
      session: session(Self.transport(config: Self.config(tiles: false, credit: nil))))
    await model.show(.light)
    #expect(model.shown == nil)
  }

  @Test func anInstanceThatLostItsCreditTakesDownWhatThePhoneHolds() async {
    await MapStyleModel(session: session(Self.transport())).show(.light)

    let model = MapStyleModel(
      session: session(Self.transport(config: Self.config(tiles: true, credit: nil))))
    await model.show(.light)
    #expect(model.shown == nil)
  }

  @Test func aFetchThatFailsLeavesWhatIsHeld() async {
    await MapStyleModel(session: session(Self.transport())).show(.light)

    let failing = Self.transport { _ in
      .json(#"{"detail":"The map style could not be read. Try again later."}"#, status: 503)
    }
    let model = MapStyleModel(session: session(failing))
    await model.show(.light)
    #expect(model.shown?.styleJSON == Self.style)
  }

  @Test func aFetchThatFailsWithNothingHeldIsNoMapAndIsAskedAgainOnlyWhenTheFormAppears() async {
    let failing = Self.transport { _ in .json(#"{"detail":"no"}"#, status: 503) }
    let session = session(failing)
    let model = MapStyleModel(session: session)
    await model.show(.light)
    #expect(model.shown == nil)
    #expect(styleRequests(failing).count == 1)

    await MapStyleModel(session: session).show(.light)
    #expect(styleRequests(failing).count == 2)
  }

  @Test func aStyleIsAskedForOncePerLaunch() async {
    let transport = Self.transport()
    let session = session(transport)
    await MapStyleModel(session: session).show(.light)
    let model = MapStyleModel(session: session)
    await model.show(.light)
    #expect(model.shown?.styleJSON == Self.style)
    #expect(styleRequests(transport).count == 1)

    await model.show(.dark)
    #expect(styleRequests(transport).count == 2)
  }

  @Test func theNextLaunchRevalidatesWithTheETagAndKeepsTheHeldStyleOn304() async throws {
    await MapStyleModel(session: session(Self.transport())).show(.light)

    let online = Self.transport { _ in StubTransport.Response(status: 304) }
    let model = MapStyleModel(session: session(online))
    await model.show(.light)
    #expect(model.shown?.styleJSON == Self.style)
    let request = try #require(styleRequests(online).first)
    #expect(request.value(forHTTPHeaderField: "If-None-Match") == #""v1""#)
  }

  @Test func aChangedStyleReplacesTheHeldOneAndItsETag() async throws {
    await MapStyleModel(session: session(Self.transport())).show(.light)

    let moved = #"{"version":8,"name":"Moved"}"#
    let changed = Self.transport { _ in Self.served(moved, etag: #""v2""#) }
    let model = MapStyleModel(session: session(changed))
    await model.show(.light)
    #expect(model.shown?.styleJSON == moved)

    let online = Self.transport { _ in StubTransport.Response(status: 304) }
    let relaunched = MapStyleModel(session: session(online))
    await relaunched.show(.light)
    #expect(relaunched.shown?.styleJSON == moved)
    #expect(styleRequests(online).first?.value(forHTTPHeaderField: "If-None-Match") == #""v2""#)
  }

  @Test func anAnswerThatIsNoStyleIsNotHeldAndIsAskedAgain() async {
    let portal = Self.transport { _ in
      StubTransport.Response(body: Data("<html>Sign in to the Wi-Fi</html>".utf8))
    }
    let session = session(portal)
    let model = MapStyleModel(session: session)
    await model.show(.light)
    #expect(model.shown == nil)
    #expect(heldStyles(session).isEmpty)

    await model.show(.light)
    #expect(styleRequests(portal).count == 2)
  }

  @Test func aSupersededShowLandsNothing() async {
    let gate = Gate()
    let transport = GatedStyles(gate: gate, held: "GET map-style/light")
    let model = MapStyleModel(session: session(transport))
    let first = Task { await model.show(.light) }
    await gate.untilArrived()
    await model.show(.dark)
    await gate.open()
    await first.value
    #expect(model.shown?.styleJSON == #"{"name":"GET map-style/dark"}"#)
  }

  @Test func prunedTilesLeaveTheStyleAlone() async throws {
    let transport = StubTransport { request in
      let route = StubTransport.routeKey(request)
      return route.hasPrefix("GET map-style/") ? Self.served() : .init(body: Data([1]))
    }
    let session = session(transport)
    let directory = session.store.directory(for: Self.origin)
      .appendingPathComponent("MapTiles", isDirectory: true)
    let store = MapTileStore(
      client: try session.requireClient(), directory: directory, language: nil)
    _ = await store.fetchStyle(.light)
    for tile in 0..<500 {
      try Data([1]).write(to: directory.appendingPathComponent("old-\(tile).webp"))
    }
    _ = await store.fetch(MapTileAddress(theme: .light, z: 1, x: 0, y: 0))
    let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    #expect(names.filter { $0.hasSuffix(".webp") }.count < 500)
    #expect(names.contains("style-light-none.json"))
    #expect(names.contains("style-light-none.etag"))
    #expect(await store.style(.light) == Self.style)
  }

  @Test func forgettingTheServerRemovesTheStyle() async throws {
    let session = session(Self.transport())
    await MapStyleModel(session: session).show(.light)
    #expect(!heldStyles(session).isEmpty)
    try session.forget(Self.origin)
    #expect(heldStyles(session).isEmpty)
  }

  #if canImport(Darwin)
    @Test func theStyleIsLeftOutOfBackups() async throws {
      let session = session(Self.transport())
      await MapStyleModel(session: session).show(.light)
      let directory = session.store.directory(for: Self.origin)
        .appendingPathComponent("MapTiles", isDirectory: true)
      let values = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
      #expect(values.isExcludedFromBackup == true)
    }
  #endif
}

/// Answers `/config` at once and a style with its own route, holding `held` at the gate.
private final class GatedStyles: HTTPTransport {
  let gate: Gate
  let held: String

  init(gate: Gate, held: String) {
    self.gate = gate
    self.held = held
  }

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let route = StubTransport.routeKey(request)
    if route == held { await gate.pass() }
    let body =
      route.hasPrefix("GET map-style/")
      ? #"{"name":"\#(route)"}"#
      : #"{"registration_mode":"invite","project_operated":true,"map_tiles":true,"#
        + #""map_attribution":"[OpenFreeMap](https://openfreemap.org/)"}"#
    let response = HTTPURLResponse(
      url: request.url!, statusCode: 200, httpVersion: nil,
      headerFields: ["Content-Type": "application/json"])!
    return (Data(body.utf8), response)
  }

  func upload(_ request: URLRequest, fromFile _: URL) async throws -> (Data, HTTPURLResponse) {
    try await send(request)
  }
}
