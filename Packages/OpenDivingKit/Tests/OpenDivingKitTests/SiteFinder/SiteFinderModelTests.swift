import Foundation
import Synchronization
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The phone's location for the finder: a fix, a refusal, or no fix, and whether it was asked.
@MainActor
final class FakeFinderLocator: LocationProvider {
  var outcome: Result<DeviceLocation, LocationFailure>
  var isUndetermined = false
  /// Holds the answer back until the test has looked at what shows meanwhile.
  var isHeld = false
  private(set) var asked = 0

  init(_ outcome: Result<DeviceLocation, LocationFailure>) {
    self.outcome = outcome
  }

  func currentLocation() async throws(LocationFailure) -> DeviceLocation {
    asked += 1
    while isHeld { await Task.yield() }
    return try outcome.get()
  }
}

/// The finder's requests: what carries the camera and the view, and what sends nothing.
@MainActor
struct SiteFinderModelTests {
  private static let today = CalendarDate(year: 2026, month: 9, day: 10)!
  private static let page = (try? KitFixture.text("dive-site-search")) ?? ""
  private static let placeRow =
    #"{"kind":"place","latitude":28.4963633,"longitude":34.5145652,"#
    + #""location":"Dahab, South Sinai, Egypt","name":"Dahab","attribution":"[OSM](https://osm.org)","#
    + #""country":"Egypt","region":"South Sinai","source":"photon","source_id":"N1","#
    + #""bbox_south":null,"bbox_north":null,"bbox_west":null,"bbox_east":null,"#
    + #""distance_m":12000,"sites_nearby":15}"#

  /// The search requests a server was sent, by their query.
  final class Searches: Sendable {
    private let urls = Mutex<[URL]>([])

    func record(_ url: URL?) {
      if let url { urls.withLock { $0.append(url) } }
    }

    var queries: [[String: String]] {
      urls.withLock { $0 }.map { url in
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
      }
    }
  }

  /// Holds the search's answers back while the test looks at what shows meanwhile; a held request
  /// that is cancelled gives up.
  final class Gate: Sendable {
    private let held = Mutex(false)

    var isHeld: Bool {
      get { held.withLock { $0 } }
      set { held.withLock { $0 = newValue } }
    }

    func pass() async throws {
      while isHeld {
        try Task.checkCancellation()
        await Task.yield()
      }
    }
  }

  /// A phone over a server answering the search with the fixture's page and empty trips and
  /// dives, its account loaded.
  private func world(
    gate: Gate = Gate(), points: String = #"{"points":[]}"#, page: String = Self.page
  ) async throws -> (FormWorld, Searches) {
    let world = try FormWorld()
    let searches = Searches()
    let empty = #"{"data":[],"total_count":0,"has_more":false,"page":1,"items_per_page":50}"#
    world.server.override { request, _ in
      switch request.route {
      case "GET dive-sites/search":
        searches.record(request.url)
        try await gate.pass()
        return .json(page)
      case "GET trips", "GET dives": return .json(empty)
      case "GET dive-sites/points": return .json(points)
      default: return nil
      }
    }
    try await world.session.loadAccount()
    return (world, searches)
  }

  private func sitesMap(_ world: FormWorld, _ locator: FakeFinderLocator) -> SiteFinderModel {
    let model = SiteFinderModel(session: world.session, locator: locator, today: Self.today)
    model.settleDelay = .zero
    return model
  }

  /// A finder over a map opened on the world, its first list answered.
  private func mapped(_ world: FormWorld, _ locator: FakeFinderLocator) async -> SiteFinderModel {
    let model = sitesMap(world, locator)
    model.hasMap = true
    model.viewport = Self.viewport
    await model.open()
    return model
  }

  /// A gesture's move to `camera`, once the list has followed it.
  private func pan(_ model: SiteFinderModel, to camera: MapCamera) async {
    model.mapMoved(to: camera, byGesture: true)
    await model.settling?.value
  }

  private static let viewport = (width: 390.0, height: 400.0)

  /// The box a request carries for `camera` over ``viewport``, as the query rounds it.
  private func box(_ camera: MapCamera) -> [String: String] {
    let sent = DiveSiteSearchQuery.rounded(
      camera.bounds(width: Self.viewport.width, height: Self.viewport.height))
    return [
      "south": DiveSiteSearchQuery.text(sent.south), "north": DiveSiteSearchQuery.text(sent.north),
      "west": DiveSiteSearchQuery.text(sent.west), "east": DiveSiteSearchQuery.text(sent.east),
    ]
  }

  private func sentBox(_ query: [String: String]) -> [String: String] {
    query.filter { ["south", "north", "west", "east"].contains($0.key) }
  }

  @Test func theFirstRequestCarriesTheCameraItOpenedOnRounded() async throws {
    let (world, searches) = try await world()
    let model = sitesMap(
      world, FakeFinderLocator(.success(.init(latitude: 12.3456, longitude: 56.789))))
    await model.open()
    let sent = try #require(searches.queries.first)
    #expect(sent["latitude"] == "12.35")
    #expect(sent["longitude"] == "56.79")
    #expect(sent["south"] == nil)
    #expect(sent["items_per_page"] == "25")
    #expect(model.camera.zoom == SiteFinderOpening.pointZoom)
    #expect(model.rows.count == 3)
    #expect(world.server.count("GET trips") == 0)
  }

  @Test func aFinderOpenedOnTheWorldSendsNoCameraAndNoBox() async throws {
    let (world, searches) = try await world()
    let model = sitesMap(world, FakeFinderLocator(.failure(.denied)))
    await model.open()
    #expect(world.server.count("GET trips") == 1)
    #expect(world.server.count("GET dives") == 1)
    let sent = try #require(searches.queries.first)
    #expect(sent["latitude"] == nil)
    #expect(sent["south"] == nil)
    #expect(model.camera == .world)
  }

  @Test func withAMapTheOpeningListsTheSitesInView() async throws {
    let (world, searches) = try await world()
    let model = sitesMap(world, FakeFinderLocator(.success(.init(latitude: 28.5, longitude: 34.5))))
    model.hasMap = true
    model.viewport = Self.viewport
    await model.open()
    #expect(searches.queries.count == 1)
    #expect(sentBox(try #require(searches.queries.last)) == box(model.camera))
  }

  @Test func aMapMeasuredAfterTheOpeningSendsItAgainNarrowed() async throws {
    let (world, searches) = try await world()
    let model = sitesMap(world, FakeFinderLocator(.success(.init(latitude: 28.5, longitude: 34.5))))
    await model.open()
    #expect(searches.queries.last?["south"] == nil)
    model.hasMap = true
    model.viewport = Self.viewport
    while searches.queries.count < 2 { await Task.yield() }
    #expect(sentBox(try #require(searches.queries.last)) == box(model.camera))
    model.viewport = (width: 390, height: 600)
    for _ in 0..<20 { await Task.yield() }
    #expect(searches.queries.count == 2)
  }

  /// The opening fits its places to the map once it is measured, and the panel moving after
  /// that leaves the camera where it is.
  @Test func theOpeningIsFittedOnceAndThePanelMovingMovesNoCamera() async throws {
    let (world, _) = try await world()
    let form = await world.form(.create)
    form.addFound(
      DiveSiteLookupItem(ref: .server(UUID()), name: "Canyon", latitude: 28.5, longitude: 34.5))
    form.addFound(
      DiveSiteLookupItem(ref: .server(UUID()), name: "Bells", latitude: 28.6, longitude: 34.6))
    let model = SiteFinderModel(form: form, locator: FakeFinderLocator(.failure(.denied)))
    model.hasMap = true
    await model.open()
    let unmeasured = model.camera
    model.viewport = Self.viewport
    let fitted = model.camera
    #expect(fitted != unmeasured)
    model.viewport = (width: 390, height: 600)
    #expect(model.camera == fitted)
    model.viewport = (width: 390, height: 150)
    #expect(model.camera == fitted)
  }

  @Test func aPanListsTheViewOnceTheCameraRests() async throws {
    let (world, searches) = try await world()
    let model = await mapped(world, FakeFinderLocator(.failure(.denied)))
    await model.open()
    model.mapMoved(to: MapCamera(latitude: 28.5, longitude: 34.5, zoom: 10), byGesture: false)
    #expect(model.settling == nil)
    #expect(searches.queries.count == 1)
    let moved = MapCamera(latitude: 28.51, longitude: 34.53, zoom: 10)
    await pan(model, to: moved)
    #expect(searches.queries.count == 2)
    let sent = try #require(searches.queries.last)
    #expect(sent["latitude"] == "28.51")
    #expect(sent["longitude"] == "34.53")
    #expect(sentBox(sent) == box(moved))
    #expect(!model.isSearching)
  }

  @Test func movesInQuickSuccessionSendOneRequest() async throws {
    let (world, searches) = try await world()
    let model = await mapped(world, FakeFinderLocator(.failure(.denied)))
    model.settleDelay = .milliseconds(50)
    model.mapMoved(to: MapCamera(latitude: 28.5, longitude: 34.5, zoom: 10), byGesture: true)
    let last = MapCamera(latitude: 28.6, longitude: 34.6, zoom: 10)
    model.mapMoved(to: last, byGesture: true)
    #expect(!model.isSearching)
    await model.settling?.value
    #expect(searches.queries.count == 2)
    #expect(sentBox(try #require(searches.queries.last)) == box(last))
  }

  @Test func aMoveCancelsTheRequestOnItsWayAndTheKeptRowsShowUndatedMeanwhile() async throws {
    let gate = Gate()
    let (world, searches) = try await world(gate: gate)
    let model = await mapped(world, FakeFinderLocator(.failure(.denied)))
    let opened = try #require(model.list)
    gate.isHeld = true
    model.mapMoved(to: MapCamera(latitude: 28.5, longitude: 34.5, zoom: 10), byGesture: true)
    while searches.queries.count < 2 { await Task.yield() }
    #expect(model.isSearching)
    #expect(model.list !== opened)
    #expect(model.list?.fetchedAt != nil)
    #expect(model.lastUpdated == nil)
    #expect(model.rows.count == 3)
    let last = MapCamera(latitude: 28.6, longitude: 34.6, zoom: 10)
    model.mapMoved(to: last, byGesture: true)
    while searches.queries.count < 3 { await Task.yield() }
    gate.isHeld = false
    await model.settling?.value
    while model.isSearching { await Task.yield() }
    #expect(searches.queries.count == 3)
    #expect(model.list?.phase == .loaded)
    #expect(model.list?.lastUpdated == nil)
    #expect(sentBox(try #require(searches.queries.last)) == box(last))
  }

  @Test func aPanCancellingTheListOnScreenShowsNoFailure() async throws {
    let gate = Gate()
    let (world, searches) = try await world(gate: gate)
    let model = await mapped(world, FakeFinderLocator(.failure(.denied)))
    gate.isHeld = true
    let toggled = Task { await model.setYours(true) }
    while searches.queries.count < 2 { await Task.yield() }
    let shown = try #require(model.list)
    model.mapMoved(to: MapCamera(latitude: 28.5, longitude: 34.5, zoom: 10), byGesture: true)
    await toggled.value
    #expect(shown.phase == .idle)
    #expect(shown.pageError == nil)
    gate.isHeld = false
    await model.settling?.value
    while model.isSearching { await Task.yield() }
    #expect(model.list?.phase == .loaded)
    #expect(searches.queries.last?["my"] == "true")
  }

  @Test func aPanBackToTheViewLastAnsweredSendsNothing() async throws {
    let (world, searches) = try await world()
    let model = await mapped(world, FakeFinderLocator(.failure(.denied)))
    let here = MapCamera(latitude: 28.5, longitude: 34.5, zoom: 10)
    await pan(model, to: here)
    let answered = try #require(model.list)
    await pan(model, to: here)
    #expect(searches.queries.count == 2)
    #expect(model.list === answered)
  }

  @Test func yourSitesIsNarrowedToTheViewAndAskedForOncePerView() async throws {
    let (world, searches) = try await world()
    let model = await mapped(world, FakeFinderLocator(.failure(.denied)))
    let first = MapCamera(latitude: 28.5, longitude: 34.5, zoom: 10)
    await pan(model, to: first)
    let all = try #require(model.list)
    await model.setYours(true)
    #expect(searches.queries.count == 3)
    let toggled = try #require(searches.queries.last)
    #expect(toggled["my"] == "true")
    #expect(sentBox(toggled) == box(first))
    let yours = try #require(model.list)

    await model.setYours(false)
    #expect(model.list === all)
    await model.setYours(true)
    #expect(model.list === yours)
    #expect(searches.queries.count == 3)

    let moved = MapCamera(latitude: 28.6, longitude: 34.6, zoom: 10)
    await pan(model, to: moved)
    let searched = try #require(searches.queries.last)
    #expect(searched["my"] == "true")
    #expect(sentBox(searched) == box(moved))
    await model.setYours(false)
    let off = try #require(searches.queries.last)
    #expect(searches.queries.count == 5)
    #expect(off["my"] == nil)
    #expect(sentBox(off) == box(model.camera))
  }

  @Test func theWholeListEndsOnAddingASiteOnceItsLastPageIsIn() async throws {
    let (paged, _) = try await world()
    let more = await mapped(paged, FakeFinderLocator(.failure(.denied)))
    #expect(more.list?.hasMore == true)
    #expect(!more.offersAddingSite)

    let last = Self.page.replacingOccurrences(of: #""has_more": true"#, with: #""has_more": false"#)
    let (world, _) = try await world(page: last)
    let model = await mapped(world, FakeFinderLocator(.failure(.denied)))
    #expect(model.offersAddingSite)
    await model.setYours(true)
    #expect(!model.offersAddingSite)
    await model.setYours(false)
    #expect(model.offersAddingSite)
  }

  @Test func aTypedSearchLooksEverywhere() async throws {
    let (world, searches) = try await world()
    let model = sitesMap(world, FakeFinderLocator(.success(.init(latitude: 28.5, longitude: 34.5))))
    model.hasMap = true
    model.viewport = Self.viewport
    await model.open()
    model.text = "Blue Hole"
    await model.typed()
    let sent = try #require(searches.queries.last)
    #expect(sent["q"] == "Blue Hole")
    #expect(sent["latitude"] == "28.50")
    #expect(sent["south"] == nil)
    model.text = ""
    await model.typed()
    #expect(sentBox(try #require(searches.queries.last)) == box(model.camera))
  }

  @Test func typingSendsOneRequestPerTextAndPickingAPlaceListsTheSitesNearIt() async throws {
    let (world, searches) = try await world()
    let model = sitesMap(world, FakeFinderLocator(.failure(.denied)))
    await model.open()
    model.text = "Dahab"
    await model.typed()
    await model.typed()
    #expect(searches.queries.count == 2)
    #expect(searches.queries.last?["q"] == "Dahab")
    #expect(model.isTyped)

    let place = try APICoding.decoder().decode(PlaceSearchItem.self, from: Data(Self.placeRow.utf8))
    await model.pick(place)
    await model.typed()
    #expect(model.text.isEmpty)
    let sent = try #require(searches.queries.last)
    #expect(searches.queries.count == 3)
    #expect(sent["q"] == nil)
    #expect(sent["latitude"] == "28.50")
    #expect(sent["longitude"] == "34.51")
    #expect(sent["south"] == nil)
  }

  @Test func useMyLocationMovesTheMapWhichTheListFollows() async throws {
    let (world, searches) = try await world()
    let locator = FakeFinderLocator(.failure(.denied))
    let model = await mapped(world, locator)
    locator.outcome = .success(.init(latitude: -8.27, longitude: 115.6))
    model.settleDelay = .milliseconds(50)
    await model.useMyLocation()
    #expect(model.camera.latitude == -8.27)
    #expect(searches.queries.count == 1)
    await model.settling?.value
    #expect(searches.queries.count == 2)
    let sent = try #require(searches.queries.last)
    #expect(sent["latitude"] == "-8.27")
    #expect(sentBox(sent) == box(model.camera))
    await model.useMyLocation()
    await model.settling?.value
    #expect(searches.queries.count == 2)
  }

  @Test func useMyLocationZoomsInButNeverOut() async throws {
    let (world, _) = try await world()
    let locator = FakeFinderLocator(.success(.init(latitude: -8.27, longitude: 115.6)))
    let model = await mapped(world, locator)
    await model.useMyLocation()
    #expect(model.camera.zoom == SiteFinderOpening.pointZoom)
    #expect(model.glides)
    model.mapMoved(to: MapCamera(latitude: 0, longitude: 0, zoom: 14), byGesture: true)
    await model.useMyLocation()
    #expect(model.camera == MapCamera(latitude: -8.27, longitude: 115.6, zoom: 14))
  }

  @Test func withNoMapUseMyLocationSearchesAtOnce() async throws {
    let (world, searches) = try await world()
    let locator = FakeFinderLocator(.failure(.denied))
    let model = sitesMap(world, locator)
    await model.open()
    locator.outcome = .success(.init(latitude: -8.27, longitude: 115.6))
    await model.useMyLocation()
    #expect(searches.queries.last?["latitude"] == "-8.27")
  }

  @Test func aRefusedLocationSaysToAllowItInSettings() async throws {
    let (world, _) = try await world()
    let model = sitesMap(world, FakeFinderLocator(.failure(.denied)))
    await model.open()
    await model.useMyLocation()
    let failure = try #require(model.locationFailure)
    #expect(SiteFinderText.locationFailure(failure).contains("Settings"))
    #expect(model.camera == .world)
  }

  @Test func theDiveFormOpensOnItsPinnedSiteAndLeavesItOutOfTheList() async throws {
    let (world, searches) = try await world()
    let form = await world.form(.create)
    let canyon = DiveSiteLookupItem(
      ref: .server(UUID(uuidString: "01a14b2e-0c3d-7a10-9f00-4a2b3c4d5e6f")!), name: "Canyon",
      latitude: 28.5687, longitude: 34.5372)
    form.addFound(canyon)
    let locator = FakeFinderLocator(.success(.init(latitude: 1, longitude: 2)))
    let model = SiteFinderModel(form: form, locator: locator)
    await model.open()
    #expect(locator.asked == 0)
    let sent = try #require(searches.queries.first)
    #expect(sent["latitude"] == "28.57")
    #expect(sent["longitude"] == "34.54")
    #expect(sent["until"] != nil)
    #expect(model.rows.count == 2)
    #expect(!model.rows.contains { $0.id == DiveSiteSearchRow.site(.init(site: canyon)).id })
  }

  @Test func theFinderAsksForTheLocationOnItsFirstOpenEvenWhereTheDivePlacesIt() async throws {
    let (world, _) = try await world()
    let form = await world.form(.create)
    form.addFound(
      DiveSiteLookupItem(ref: .server(UUID()), name: "Canyon", latitude: 28.5, longitude: 34.5))
    let locator = FakeFinderLocator(.failure(.denied))
    locator.isUndetermined = true
    await SiteFinderModel(form: form, locator: locator).open()
    for _ in 0..<100 where locator.asked == 0 { await Task.yield() }
    #expect(locator.asked == 1)
  }

  @Test func aNewDiveWithNothingToPlaceItListsTheDiversSitesByLastUse() async throws {
    let (world, searches) = try await world()
    let form = await world.form(.create)
    await SiteFinderModel(form: form, locator: FakeFinderLocator(.failure(.denied))).open()
    let sent = try #require(searches.queries.first)
    #expect(sent["latitude"] == nil)
    #expect(sent["until"] != nil)
  }

  @Test func withNoRouteTheSearchFailsAtOnceAndAsksForNothing() async throws {
    let (world, searches) = try await world()
    world.route.isRouteAvailable = false
    let model = sitesMap(world, FakeFinderLocator(.failure(.denied)))
    await model.open()
    #expect(model.list?.phase == .failed(.noRoute))
    #expect(searches.queries.isEmpty)
    #expect(SiteFinderText.failure(.noRoute).contains("could not be reached"))
  }

  @Test func theSitesMapShowsItsLastListAtOnce() async throws {
    let (world, _) = try await world()
    await sitesMap(world, FakeFinderLocator(.failure(.denied))).open()
    world.route.isRouteAvailable = false
    let again = sitesMap(world, FakeFinderLocator(.failure(.denied)))
    await again.open()
    #expect(again.rows.count == 3)
    #expect(again.lastUpdated != nil)
  }

  @Test func theSitesMapShowsItsLastListWhileItWaitsForAFix() async throws {
    let (world, searches) = try await world()
    await sitesMap(world, FakeFinderLocator(.failure(.denied))).open()
    let locator = FakeFinderLocator(.success(.init(latitude: 28.5, longitude: 34.5)))
    locator.isHeld = true
    let again = sitesMap(world, locator)
    let opening = Task { await again.open() }
    while locator.asked == 0 { await Task.yield() }
    #expect(again.isOpening)
    #expect(again.rows.count == 3)
    #expect(again.list?.lastUpdated != nil)
    #expect(again.lastUpdated == nil)
    #expect(searches.queries.count == 1)
    locator.isHeld = false
    await opening.value
    #expect(searches.queries.last?["latitude"] == "28.50")
    #expect(again.list?.lastUpdated == nil)
  }

  // MARK: - An opened site

  private static let canyon = UUID(uuidString: "01a14b2e-0c3d-7a10-9f00-4a2b3c4d5e6f")!

  /// A finder over a map whose points hold the diver's Canyon at 28.5687, 34.5372.
  private func withPoints() async throws -> (SiteFinderModel, Searches) {
    let (world, searches) = try await world(points: try KitFixture.text("dive-site-points"))
    let model = await mapped(world, FakeFinderLocator(.failure(.denied)))
    await model.points.load()
    return (model, searches)
  }

  /// The fixture's site, at `uuid` and placed at `latitude`, `longitude`.
  private func site(_ uuid: UUID, latitude: Double?, longitude: Double?) throws -> DiveSiteRead {
    var object = try #require(
      JSONSerialization.jsonObject(with: KitFixture.data("dive-site")) as? [String: Any])
    object["uuid"] = uuid.uuidString
    object["name"] = "Renamed"
    object["latitude"] = latitude ?? NSNull()
    object["longitude"] = longitude ?? NSNull()
    return try APICoding.decoder().decode(
      DiveSiteRead.self, from: JSONSerialization.data(withJSONObject: object))
  }

  @Test func aTouchedPointOpensInThePanelAndGlidesToTheMiddleZoomedInToTheSite() async throws {
    let (model, searches) = try await withPoints()
    await pan(model, to: MapCamera(latitude: 28, longitude: 34, zoom: 8))
    let sent = searches.queries.count
    model.select(Self.canyon)
    #expect(model.opened?.uuid == Self.canyon)
    #expect(model.opened?.name == "Canyon")
    #expect(model.opened?.mark == .proposed)
    #expect(model.selected == nil)
    #expect(
      model.camera
        == MapCamera(latitude: 28.5687, longitude: 34.5372, zoom: SiteFinderOpening.siteZoom))
    #expect(model.glides)
    // The glide's landing is the map's own move, which the list does not follow.
    model.mapMoved(to: model.camera, byGesture: false)
    #expect(model.settling == nil)
    #expect(searches.queries.count == sent)
    #expect(model.highlighted == Self.canyon)
    #expect(model.holdsOpenedSite)
    model.closeSite()
    #expect(model.opened == nil)
    #expect(model.highlighted == nil)
    #expect(!model.holdsOpenedSite)
  }

  /// The open site's own pin brings it back to the middle and keeps what its panel has read.
  @Test func theOpenSitesPinKeepsItsRead() async throws {
    let (model, _) = try await withPoints()
    model.select(Self.canyon)
    let read = try site(Self.canyon, latitude: 28.5687, longitude: 34.5372)
    model.read(read)
    await pan(model, to: MapCamera(latitude: 1, longitude: 2, zoom: 15))
    model.select(Self.canyon)
    #expect(model.opened?.site == read)
    #expect(model.camera.latitude == 28.5687)
  }

  private static let canyonRow = DiveSiteSearchItem(
    site: DiveSiteLookupItem(
      ref: .server(canyon), name: "Canyon", latitude: 28.5687, longitude: 34.5372))

  @Test func aRowOpensInThePanelZoomedInToTheSiteAndNoFurtherOut() async throws {
    let (model, _) = try await withPoints()
    #expect(model.choose(Self.canyonRow) == nil)
    #expect(model.opened?.uuid == Self.canyon)
    #expect(model.camera.zoom == SiteFinderOpening.siteZoom)
    #expect(model.camera.latitude == 28.5687)
    #expect(model.glides)
    await pan(model, to: MapCamera(latitude: 28, longitude: 34, zoom: 15))
    #expect(!model.glides)
    #expect(model.choose(Self.canyonRow) == nil)
    #expect(model.camera.zoom == 15)
  }

  @Test func aSiteOpenedByItsUuidIsCentredOnceItsPanelReadsWhereItIs() async throws {
    let (model, _) = try await withPoints()
    let other = UUID()
    let before = model.camera
    model.open(uuid: other)
    #expect(model.opened?.name == nil)
    #expect(model.opened?.mark == nil)
    #expect(model.camera == before)
    #expect(!model.holdsOpenedSite)
    // Another site's read says nothing about this one.
    model.read(try site(Self.canyon, latitude: 1, longitude: 2))
    #expect(model.opened?.name == nil)
    model.read(try site(other, latitude: 12.5, longitude: 45.25))
    #expect(model.opened?.name == "Renamed")
    #expect(model.opened?.mark == .private)
    #expect(model.opened?.location == "Dahab, Egypt")
    #expect(model.opened?.site?.uuid == other)
    #expect(model.camera.latitude == 12.5)
    #expect(model.glides)
    #expect(model.holdsOpenedSite)
    // Placed once: a later read renames it and leaves the camera where the diver took it.
    await pan(model, to: MapCamera(latitude: 3, longitude: 4, zoom: 12))
    model.read(try site(other, latitude: 12.5, longitude: 45.25))
    #expect(model.camera == MapCamera(latitude: 3, longitude: 4, zoom: 12))
  }

  @Test func aSiteWithNowhereToBeLeavesTheMapFree() async throws {
    let (model, _) = try await withPoints()
    let other = UUID()
    model.open(uuid: other)
    model.read(try site(other, latitude: nil, longitude: nil))
    #expect(model.opened?.name == "Renamed")
    #expect(!model.holdsOpenedSite)
  }

  /// The weather bar's pin and title, from whichever of the point, the row and the read said them.
  @Test func anOpenedSiteHoldsItsPinAndIsTitledByItsPlaceElseItsName() async throws {
    let (model, _) = try await withPoints()
    model.select(Self.canyon)
    #expect(model.opened?.pin == DeviceLocation(latitude: 28.5687, longitude: 34.5372))
    #expect(model.opened?.weatherTitle == "Canyon")
    model.read(try site(Self.canyon, latitude: 28.57, longitude: 34.54))
    #expect(model.opened?.pin == DeviceLocation(latitude: 28.57, longitude: 34.54))
    #expect(model.opened?.weatherTitle == "Dahab, Egypt")

    #expect(model.choose(Self.canyonRow) == nil)
    #expect(model.opened?.pin == DeviceLocation(latitude: 28.5687, longitude: 34.5372))
    model.open(uuid: UUID())
    #expect(model.opened?.pin == nil)
    #expect(model.opened?.weatherTitle == nil)
  }

  @Test func theWeatherIsTheOpenSitesElseTheSiteNearestTheMiddleOnceZoomedIn() async throws {
    let (model, _) = try await withPoints()
    // Canyon is in view, The Canyon well outside it.
    await pan(model, to: MapCamera(latitude: 28.55, longitude: 34.52, zoom: 10))
    let nearest = try #require(model.weatherSite)
    #expect(nearest.uuid == Self.canyon)
    #expect(nearest.pin == DeviceLocation(latitude: 28.5687, longitude: 34.5372))
    // The list's row names the place the point does not.
    #expect(nearest.title == "Dahab, South Sinai, Egypt")

    await pan(model, to: MapCamera(latitude: 28.55, longitude: 34.52, zoom: 8.9))
    #expect(model.weatherSite == nil)
    await pan(model, to: MapCamera(latitude: 10, longitude: 10, zoom: 12))
    #expect(model.weatherSite == nil)

    model.open(uuid: UUID())
    #expect(model.weatherSite == nil)
    model.select(Self.canyon)
    #expect(model.weatherSite?.uuid == Self.canyon)
  }

  @Test func aBoxHoldsAPositionAcrossTheAntimeridian() {
    let box = LatLonBounds(south: -10, north: 10, west: 179, east: 181)
    #expect(SiteFinderModel.contains(box, latitude: 0, longitude: -179.5))
    #expect(SiteFinderModel.contains(box, latitude: 0, longitude: 179.5))
    #expect(!SiteFinderModel.contains(box, latitude: 0, longitude: 178))
    #expect(!SiteFinderModel.contains(box, latitude: 11, longitude: 180))
  }

  @Test func theSitesMapOpenedOnASiteCentresItsPinAndAsksNothingOfTheLocation() async throws {
    let (world, searches) = try await world(points: try KitFixture.text("dive-site-points"))
    await DiveSitePointsModel(session: world.session).load()
    let locator = FakeFinderLocator(.success(.init(latitude: 1, longitude: 2)))
    let model = SiteFinderModel(
      session: world.session, locator: locator, today: Self.today, site: Self.canyon)
    await model.open()
    #expect(locator.asked == 0)
    #expect(model.opened?.uuid == Self.canyon)
    #expect(model.opened?.name == "Canyon")
    #expect(model.camera.latitude == 28.5687)
    #expect(model.camera.zoom == SiteFinderOpening.siteZoom)
    #expect(searches.queries.last?["latitude"] == "28.57")
  }

  @Test func useMyLocationClosesTheOpenedSite() async throws {
    let (model, _) = try await withPoints()
    model.select(Self.canyon)
    #expect(model.opened != nil)
    await model.useMyLocation()
    #expect(model.opened != nil)
    let located = FakeFinderLocator(.success(.init(latitude: -8.27, longitude: 115.6)))
    let (world, _) = try await world(points: try KitFixture.text("dive-site-points"))
    let again = await mapped(world, located)
    await again.points.load()
    again.select(Self.canyon)
    await again.useMyLocation()
    #expect(again.opened == nil)
    #expect(again.camera.latitude == -8.27)
  }

  @Test func theDiveFormsTouchedPointIsNamedUnderItsSheetAndOpensNothing() async throws {
    let (world, _) = try await world(points: try KitFixture.text("dive-site-points"))
    let form = await world.form(.create)
    let model = SiteFinderModel(form: form, locator: FakeFinderLocator(.failure(.denied)))
    await model.points.load()
    let before = model.camera
    model.select(Self.canyon)
    #expect(model.selected?.uuid == Self.canyon)
    #expect(model.highlighted == Self.canyon)
    #expect(model.opened == nil)
    #expect(model.camera == before)
    // A row is the form's to put on the dive.
    #expect(model.choose(Self.canyonRow) == Self.canyonRow.site)
    #expect(model.opened == nil)
  }
}
