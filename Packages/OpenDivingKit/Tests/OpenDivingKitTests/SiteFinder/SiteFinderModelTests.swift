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

  /// A phone over a server answering the search with the fixture's page and empty trips and
  /// dives, its account loaded.
  private func world() async throws -> (FormWorld, Searches) {
    let world = try FormWorld()
    let searches = Searches()
    let page = Self.page
    let empty = #"{"data":[],"total_count":0,"has_more":false,"page":1,"items_per_page":50}"#
    world.server.override { request, _ in
      switch request.route {
      case "GET dive-sites/search":
        searches.record(request.url)
        return .json(page)
      case "GET trips", "GET dives": return .json(empty)
      case "GET dive-sites/points": return .json(#"{"points":[]}"#)
      default: return nil
      }
    }
    try await world.session.loadAccount()
    return (world, searches)
  }

  private func tab(_ world: FormWorld, _ locator: FakeFinderLocator) -> SiteFinderModel {
    SiteFinderModel(session: world.session, locator: locator, today: Self.today)
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
    let model = tab(world, FakeFinderLocator(.success(.init(latitude: 12.3456, longitude: 56.789))))
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
    let model = tab(world, FakeFinderLocator(.failure(.denied)))
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
    let model = tab(world, FakeFinderLocator(.success(.init(latitude: 28.5, longitude: 34.5))))
    model.hasMap = true
    model.viewport = Self.viewport
    await model.open()
    #expect(searches.queries.count == 1)
    #expect(sentBox(try #require(searches.queries.last)) == box(model.camera))
  }

  @Test func aMapMeasuredAfterTheOpeningSendsItAgainNarrowed() async throws {
    let (world, searches) = try await world()
    let model = tab(world, FakeFinderLocator(.success(.init(latitude: 28.5, longitude: 34.5))))
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

  @Test func panningSendsNothingAndSearchThisAreaSendsTheView() async throws {
    let (world, searches) = try await world()
    let model = tab(world, FakeFinderLocator(.failure(.denied)))
    model.hasMap = true
    model.viewport = Self.viewport
    await model.open()
    model.mapMoved(to: MapCamera(latitude: 28.5, longitude: 34.5, zoom: 10), byGesture: false)
    #expect(!model.offersSearchThisArea)
    let moved = MapCamera(latitude: 28.51, longitude: 34.53, zoom: 10)
    model.mapMoved(to: moved, byGesture: true)
    #expect(model.offersSearchThisArea)
    #expect(searches.queries.count == 1)
    await model.searchThisArea()
    let sent = try #require(searches.queries.last)
    #expect(sent["latitude"] == "28.51")
    #expect(sent["longitude"] == "34.53")
    #expect(sentBox(sent) == box(moved))
    #expect(!model.offersSearchThisArea)
  }

  @Test func shownAgainAMovedMapListsItsView() async throws {
    let (world, searches) = try await world()
    let model = tab(world, FakeFinderLocator(.failure(.denied)))
    model.hasMap = true
    model.viewport = Self.viewport
    await model.open()
    await model.open()
    #expect(searches.queries.count == 1)
    let moved = MapCamera(latitude: 28.51, longitude: 34.53, zoom: 10)
    model.mapMoved(to: moved, byGesture: true)
    await model.open()
    #expect(searches.queries.count == 2)
    #expect(sentBox(try #require(searches.queries.last)) == box(moved))
  }

  @Test func yourSitesIsNotNarrowedToTheView() async throws {
    let (world, searches) = try await world()
    let model = tab(world, FakeFinderLocator(.failure(.denied)))
    model.hasMap = true
    model.viewport = Self.viewport
    await model.open()
    model.mapMoved(to: MapCamera(latitude: 28.5, longitude: 34.5, zoom: 10), byGesture: true)
    await model.setYours(true)
    model.mapMoved(to: MapCamera(latitude: 28.6, longitude: 34.6, zoom: 10), byGesture: true)
    #expect(!model.offersSearchThisArea)
    let sent = try #require(searches.queries.last)
    #expect(sent["yours"] == "true")
    #expect(sent["south"] == nil)
    await model.setYours(false)
    #expect(sentBox(try #require(searches.queries.last)) == box(model.camera))
  }

  @Test func aTypedSearchLooksEverywhere() async throws {
    let (world, searches) = try await world()
    let model = tab(world, FakeFinderLocator(.success(.init(latitude: 28.5, longitude: 34.5))))
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
    let model = tab(world, FakeFinderLocator(.failure(.denied)))
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

  @Test func useMyLocationMovesTheMapAndListsTheSitesInView() async throws {
    let (world, searches) = try await world()
    let locator = FakeFinderLocator(.failure(.denied))
    let model = tab(world, locator)
    model.hasMap = true
    model.viewport = Self.viewport
    await model.open()
    locator.outcome = .success(.init(latitude: -8.27, longitude: 115.6))
    await model.useMyLocation()
    #expect(model.camera.latitude == -8.27)
    #expect(!model.offersSearchThisArea)
    #expect(searches.queries.count == 2)
    let sent = try #require(searches.queries.last)
    #expect(sent["latitude"] == "-8.27")
    #expect(sentBox(sent) == box(model.camera))
  }

  @Test func withNoMapUseMyLocationSearchesAtOnce() async throws {
    let (world, searches) = try await world()
    let locator = FakeFinderLocator(.failure(.denied))
    let model = tab(world, locator)
    await model.open()
    locator.outcome = .success(.init(latitude: -8.27, longitude: 115.6))
    await model.useMyLocation()
    #expect(searches.queries.last?["latitude"] == "-8.27")
  }

  @Test func aRefusedLocationSaysToAllowItInSettings() async throws {
    let (world, _) = try await world()
    let model = tab(world, FakeFinderLocator(.failure(.denied)))
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
    let model = tab(world, FakeFinderLocator(.failure(.denied)))
    await model.open()
    #expect(model.list?.phase == .failed(.noRoute))
    #expect(searches.queries.isEmpty)
    #expect(SiteFinderText.failure(.noRoute).contains("could not be reached"))
  }

  @Test func theTabShowsItsLastListAtOnce() async throws {
    let (world, _) = try await world()
    await tab(world, FakeFinderLocator(.failure(.denied))).open()
    world.route.isRouteAvailable = false
    let again = tab(world, FakeFinderLocator(.failure(.denied)))
    await again.open()
    #expect(again.rows.count == 3)
    #expect(again.list?.lastUpdated != nil)
  }

  @Test func theTabShowsItsLastListWhileItWaitsForAFix() async throws {
    let (world, searches) = try await world()
    await tab(world, FakeFinderLocator(.failure(.denied))).open()
    let locator = FakeFinderLocator(.success(.init(latitude: 28.5, longitude: 34.5)))
    locator.isHeld = true
    let again = tab(world, locator)
    let opening = Task { await again.open() }
    while locator.asked == 0 { await Task.yield() }
    #expect(again.isOpening)
    #expect(again.rows.count == 3)
    #expect(again.list?.lastUpdated != nil)
    #expect(searches.queries.count == 1)
    locator.isHeld = false
    await opening.value
    #expect(searches.queries.last?["latitude"] == "28.50")
    #expect(again.list?.lastUpdated == nil)
  }
}
