import Foundation
import OpenDivingKit
import Synchronization
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A page head's map asks for its tiles only where the instance draws them and names their
/// credit, shows a set whole or not at all, and keeps what it was shown for the next launch.
@MainActor
struct MapBackdropModelTests {
  private static let origin = ServerOrigin("https://dive.example.org")!
  private static let credit = "[OpenFreeMap](https://openfreemap.org/)"
  private static let site = MapPoint(name: "Blue Hole", latitude: 28.5722, longitude: 34.5372)

  private let support = FileManager.default.temporaryDirectory
    .appendingPathComponent("MapBackdropModelTests-\(UUID().uuidString)", isDirectory: true)

  private func session(
    _ transport: any HTTPTransport, now: @escaping @Sendable () -> Date = { Date() }
  ) -> Session {
    Session(
      transport: transport,
      secrets: InMemorySecretStore([Self.origin.description: "refresh"]),
      activeOrigin: InMemoryActiveOriginStore(Self.origin), background: NoBackgroundExecution(),
      applicationSupport: support,
      userAgent: UserAgent(appVersion: "0", systemVersion: "0", model: "iPhone"),
      accessToken: "access", now: now)
  }

  private func configRequests(_ transport: StubTransport) -> Int {
    transport.requests.filter { StubTransport.routeKey($0) == "GET config" }.count
  }

  private static func config(tiles: Bool, credit: String?) -> StubTransport.Response {
    let attribution = credit.map { #""\#($0)""# } ?? "null"
    return .json(
      #"{"registration_mode":"invite","project_operated":true,"map_tiles":\#(tiles),"#
        + #""map_attribution":\#(attribution)}"#)
  }

  /// Answers `/config`, `/health` and every tile, a tile's bytes being its path.
  private static func transport(
    config: StubTransport.Response,
    tile: @escaping @Sendable (URLRequest) -> StubTransport.Response =
      { request in
        StubTransport.Response(
          headers: ["Content-Type": "image/webp", "ETag": #""v1""#],
          body: Data(StubTransport.routeKey(request).utf8))
      }
  ) -> StubTransport {
    StubTransport { request in
      let route = StubTransport.routeKey(request)
      if route == "GET config" { return config }
      if route == "GET health" { return .json(#"{"version":"1","commit":"x"}"#) }
      if route.hasPrefix("GET map-tiles/") { return tile(request) }
      return .json(#"{"detail":"Not Found"}"#, status: 404)
    }
  }

  private var layout: MapBackdropLayout {
    MapBackdropLayout(
      points: [Self.site], fixes: [], theme: .dark, width: 393, height: 280, coveredBottom: 150)!
  }

  private func tileRequests(_ transport: StubTransport) -> [URLRequest] {
    transport.requests.filter { StubTransport.routeKey($0).hasPrefix("GET map-tiles/") }
  }

  @Test func asksForEveryTileWithTheBearerAndShowsThemWithTheCredit() async throws {
    let transport = Self.transport(config: Self.config(tiles: true, credit: Self.credit))
    let model = MapBackdropModel(session: session(transport))
    await model.show(layout)

    let shown = try #require(model.shown)
    #expect(model.credit == Self.credit)
    #expect(Set(shown.images.keys) == Set(layout.tiles.map(\.address)))
    let requests = tileRequests(transport)
    #expect(
      Set(requests.map(StubTransport.routeKey))
        == ["GET map-tiles/dark/9/304/213", "GET map-tiles/dark/9/305/213"])
    #expect(requests.allSatisfy { $0.bearer == "access" })
  }

  @Test func anInstanceThatDrawsNoTilesIsAskedForNone() async {
    let transport = Self.transport(config: Self.config(tiles: false, credit: nil))
    let model = MapBackdropModel(session: session(transport))
    await model.show(layout)
    #expect(model.shown == nil)
    #expect(tileRequests(transport).isEmpty)
  }

  @Test func tilesWithNoCreditYetAreNotAskedForAndTheConfigAgainOnlyOnceStale() async {
    let transport = Self.transport(config: Self.config(tiles: true, credit: nil))
    let clock = Mutex(Date(timeIntervalSince1970: 0))
    let session = session(transport, now: { clock.withLock { $0 } })
    let model = MapBackdropModel(session: session)
    await model.show(layout)
    clock.withLock { $0 += Session.serverInfoFreshness - 1 }
    await MapBackdropModel(session: session).show(layout)
    #expect(model.shown == nil)
    #expect(model.credit == nil)
    #expect(tileRequests(transport).isEmpty)
    #expect(configRequests(transport) == 1)

    clock.withLock { $0 += 1 }
    await MapBackdropModel(session: session).show(layout)
    #expect(configRequests(transport) == 2)
  }

  @Test func theServersAnswerToAScreenServesAPageHead() async {
    let transport = Self.transport(config: Self.config(tiles: true, credit: nil))
    let session = session(transport)
    await session.loadServerInfo()
    await MapBackdropModel(session: session).show(layout)
    #expect(configRequests(transport) == 1)
  }

  @Test func oneTileThatCannotBeHadLeavesNoMapButKeepsTheCredit() async {
    let transport = Self.transport(config: Self.config(tiles: true, credit: Self.credit)) {
      request in
      StubTransport.routeKey(request).hasSuffix("/305/213")
        ? .json(#"{"detail":"The map tile could not be drawn."}"#, status: 503)
        : StubTransport.Response(headers: ["ETag": #""v1""#], body: Data([1]))
    }
    let model = MapBackdropModel(session: session(transport))
    await model.show(layout)
    #expect(model.shown == nil)
    #expect(model.credit == Self.credit)
  }

  @Test func theNextLaunchShowsWhatWasShownOfflineAndRevalidatesOnline() async throws {
    let first = Self.transport(config: Self.config(tiles: true, credit: Self.credit))
    await MapBackdropModel(session: session(first)).show(layout)

    let offline = StubTransport { _ in throw URLError(.notConnectedToInternet) }
    let model = MapBackdropModel(session: session(offline))
    await model.show(layout)
    #expect(model.credit == Self.credit)
    #expect(model.shown?.images.count == layout.tiles.count)

    let online = Self.transport(config: Self.config(tiles: true, credit: Self.credit)) { _ in
      StubTransport.Response(status: 304)
    }
    let relaunched = MapBackdropModel(session: session(online))
    await relaunched.show(layout)
    #expect(relaunched.shown != nil)
    #expect(
      tileRequests(online).allSatisfy { $0.value(forHTTPHeaderField: "If-None-Match") == #""v1""# })
    #expect(tileRequests(online).count == layout.tiles.count)
  }

  @Test func anInstanceThatStoppedDrawingTilesTakesDownWhatThePhoneHolds() async {
    let first = Self.transport(config: Self.config(tiles: true, credit: Self.credit))
    await MapBackdropModel(session: session(first)).show(layout)

    let model = MapBackdropModel(
      session: session(Self.transport(config: Self.config(tiles: false, credit: nil))))
    await model.show(layout)
    #expect(model.shown == nil)
    #expect(model.credit == nil)
  }

  #if canImport(Darwin)
    @Test func theTilesAreLeftOutOfBackups() async throws {
      let transport = Self.transport(config: Self.config(tiles: true, credit: Self.credit))
      let session = session(transport)
      await MapBackdropModel(session: session).show(layout)
      let directory = session.store.directory(for: Self.origin)
        .appendingPathComponent("MapTiles", isDirectory: true)
      let values = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
      #expect(values.isExcludedFromBackup == true)
    }
  #endif

  @Test func aTileAskedForOnceIsNotAskedAgainThisLaunch() async {
    let transport = Self.transport(config: Self.config(tiles: true, credit: Self.credit))
    let session = session(transport)
    await MapBackdropModel(session: session).show(layout)
    await MapBackdropModel(session: session).show(layout)
    #expect(tileRequests(transport).count == layout.tiles.count)
  }

  @Test func aHeadThatLeavesWhileTheConfigIsAskedLeavesItToTheNextHead() async {
    let gate = Gate()
    let inner = Self.transport(config: Self.config(tiles: true, credit: Self.credit))
    let session = session(FirstConfig(inner: inner, gate: gate))
    let leaving = Task { await MapBackdropModel(session: session).show(layout) }
    await gate.untilArrived()
    leaving.cancel()
    let next = MapBackdropModel(session: session)
    let showing = Task { await next.show(layout) }
    await gate.open()
    await showing.value
    #expect(next.shown != nil)
    #expect(configRequests(inner) == 1)
  }

  @Test func aConfigThatCouldNotBeHadIsAskedAgainByTheNextHead() async {
    let inner = Self.transport(config: Self.config(tiles: true, credit: Self.credit))
    let session = session(FirstConfig(inner: inner, gate: nil))
    await MapBackdropModel(session: session).show(layout)
    let next = MapBackdropModel(session: session)
    await next.show(layout)
    #expect(next.shown != nil)
  }
}

/// Holds the first `GET config` at `gate`, or with no gate fails it as unreachable.
private final class FirstConfig: HTTPTransport {
  let inner: StubTransport
  private let gate: Gate?
  private let first = Mutex(true)

  init(inner: StubTransport, gate: Gate?) {
    self.inner = inner
    self.gate = gate
  }

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let isFirst =
      StubTransport.routeKey(request) == "GET config"
      && first.withLock { first in
        defer { first = false }
        return first
      }
    if isFirst {
      guard let gate else { throw URLError(.timedOut) }
      await gate.pass()
    }
    return try await inner.send(request)
  }

  func upload(_ request: URLRequest, fromFile file: URL) async throws -> (Data, HTTPURLResponse) {
    try await inner.upload(request, fromFile: file)
  }
}
