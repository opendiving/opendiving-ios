import Foundation
import Observation

/// The site finder: a map, the list of `GET /dive-sites/search` beside it, a search box, the
/// *Your sites* filter and the camera, for the Sites tab and the dive form's site picker alike.
///
/// **The camera is the anchor.** Every request carries the camera's centre — unless the finder
/// rests, unmoved, on the world its opening rule ended on, which sends none and lists the diver's
/// sites by last use. What moved the camera is never sent: a pan, a picked place, the dive's fix
/// and *Use my location* only move it.
///
/// **Untyped, the list is the sites in view.** The opening, *Use my location*, a picked place,
/// *Your sites* toggled and *Search this area* each send the part of the map the diver sees as a
/// box; a pan sends nothing and offers *Search this area*. A typed search looks everywhere,
/// nearest the camera first, and *Your sites* lists every one of the diver's, which the server
/// does not narrow to a view.
///
/// **The list is the server's order.** Nothing re-sorts or re-filters it, except that the dive
/// form leaves out a site already on the dive.
@MainActor
@Observable
public final class SiteFinderModel {
  public enum Host: Hashable, Sendable {
    /// The Sites tab: a row opens the site's page.
    case sitesTab
    /// The dive form's site picker: a row puts the site on the dive.
    case diveForm
  }

  public let host: Host
  /// What is typed, which ``typed()`` searches once the diver pauses.
  public var text = ""
  /// *Your sites*: only the diver's own sites and the Commons records they saved.
  public private(set) var yours = false
  /// Where the map looks. A change moves the map there; the map's own moves come back through
  /// ``mapMoved(to:byGesture:)``.
  public private(set) var camera = MapCamera.world
  /// The opening rule has not answered yet, and the camera waits on the world.
  public private(set) var isOpening = true
  public private(set) var list: PagedList<DiveSiteSearchRow>?
  /// The camera moved since the last request, outside *Your sites*, whose list ignores the view.
  public private(set) var offersSearchThisArea = false
  public private(set) var isLocating = false
  /// Why the last *Use my location* found nothing.
  public private(set) var locationFailure: LocationFailure?
  /// The point the diver touched on the map.
  public var selected: SiteFinderPoint?
  public let points: DiveSitePointsModel
  /// Whether the map is drawn: without one there is no view to narrow the list to.
  public var hasMap = false {
    didSet { narrowOpening() }
  }
  /// The part of the map the diver sees, in points: what the opening fits its places to and the
  /// box an untyped list is narrowed to.
  @ObservationIgnored public var viewport = (width: 0.0, height: 0.0) {
    didSet {
      refit()
      narrowOpening()
    }
  }

  /// The query the list shows.
  public private(set) var query: DiveSiteSearchQuery?

  /// The list shows a typed search.
  public var isTyped: Bool { !(query?.text.trimmedOfWhitespace.isEmpty ?? true) }

  @ObservationIgnored private let session: Session
  @ObservationIgnored private let locator: any LocationProvider
  @ObservationIgnored private let form: DiveFormModel?
  /// The day a trip part must hold for the Sites tab to open on it.
  @ObservationIgnored private let today: CalendarDate?
  @ObservationIgnored private var opening: SiteFinderOpening?
  @ObservationIgnored private var isResolving = false
  /// The camera sits, unmoved, on the world the opening rule ended on.
  @ObservationIgnored private var restsOnWorld = false
  /// The camera sits, unmoved, where the opening put it, so a map measured late is fitted again.
  @ObservationIgnored private var restsOnOpening = false

  /// The Sites tab's finder.
  public init(session: Session, locator: any LocationProvider, today: CalendarDate) {
    self.session = session
    self.locator = locator
    self.today = today
    form = nil
    host = .sitesTab
    points = DiveSitePointsModel(session: session)
  }

  /// The dive form's finder, which reads the form for where it opens, ranks by the dive's start
  /// and leaves out the sites already on the dive.
  public init(form: DiveFormModel, locator: any LocationProvider) {
    session = form.session
    self.locator = locator
    self.form = form
    today = nil
    host = .diveForm
    points = DiveSitePointsModel(session: form.session)
  }

  /// The rows to show, in the server's order.
  public var rows: [DiveSiteSearchRow] {
    guard let list else { return [] }
    let excluded = Set(form?.values.diveSites ?? [])
    guard !excluded.isEmpty else { return list.items }
    return list.items.filter { row in
      if case .site(let site) = row { return !excluded.contains(site.ref) }
      return true
    }
  }

  // MARK: - Opening

  /// Runs the host's opening rule once, moves the camera once, and sends the first request with
  /// the camera it opened on. Shown again, a list the map has moved away from follows the view.
  public func open() async {
    guard isOpening else {
      if offersSearchThisArea, !isTyped { await searchThisArea() }
      return
    }
    guard !isResolving else { return }
    isResolving = true
    showKeptWhileOpening()
    let opened: SiteFinderOpening
    if let form {
      let facts = form.siteFinderFacts
      var location: DeviceLocation?
      if facts.needsLocation {
        location = try? await locator.currentLocation()
      } else if locator.isUndetermined {
        // The prompt belongs to the finder's first open, whichever host that is.
        Task { _ = try? await locator.currentLocation() }
      }
      opened = .diveForm(facts, location: location)
    } else if let location = try? await locator.currentLocation() {
      opened = .point(location)
    } else if let today {
      let (trips, dives) = await tripsAndLastDive()
      opened = .sitesTab(location: nil, trips: trips, dives: dives, today: today)
    } else {
      opened = .world
    }
    opening = opened
    restsOnWorld = opened.isWorld
    restsOnOpening = true
    camera = opened.camera(width: viewport.width, height: viewport.height)
    isOpening = false
    isResolving = false
    await search()
  }

  /// The trip list's first page and the newest dive, as the server answers them, else as the
  /// Trips and Dives tabs last showed them.
  private func tripsAndLastDive() async -> ([TripRead], [DiveListItem]) {
    let cache = AccountStores.current(session)?.cache
    var trips = cache?.pages(PageCacheKey<TripRead>.trips.name, of: TripRead.self)?.value.items
    var dives = cache?.pages(PageCacheKey<DiveListItem>.dives.name, of: DiveListItem.self)?.value
      .items
    if let client = try? session.routedClient() {
      async let tripPage = try? client.trips(page: 1)
      async let divePage = try? client.dives(page: 1, itemsPerPage: 1)
      if let page = await tripPage { trips = page.data }
      if let page = await divePage { dives = page.data }
    }
    return (trips ?? [], Array((dives ?? []).prefix(1)))
  }

  /// The Sites tab's last untyped list, shown while the opening rule waits on a fix or a read,
  /// as every list shows its kept pages at once; the opening's own request replaces it.
  private func showKeptWhileOpening() {
    guard host == .sitesTab else { return }
    let kept = PagedList<DiveSiteSearchRow>(
      session: session, cache: .siteFinder(yours: false), routed: true
    ) { _, _, _ in throw APIError.noRoute }
    kept.showKept()
    list = kept
  }

  private func refit() {
    guard restsOnOpening, let opening else { return }
    camera = opening.camera(width: viewport.width, height: viewport.height)
  }

  /// The opening's list again, narrowed to the view, where it was sent before a map was drawn and
  /// measured to say what the view is.
  private func narrowOpening() {
    guard restsOnOpening, !isOpening, !isTyped, query?.box == nil, shownBox != nil else { return }
    Task { await search() }
  }

  // MARK: - The diver

  /// The map came to rest: a gesture's move, or its account of one asked of it.
  public func mapMoved(to camera: MapCamera, byGesture: Bool) {
    self.camera = camera
    guard byGesture, !isOpening else { return }
    restsOnWorld = false
    restsOnOpening = false
    if !yours { offersSearchThisArea = true }
  }

  /// The search box's text, once the diver has paused: nothing is sent for text already searched.
  public func typed() async {
    guard !isOpening, text.trimmedOfWhitespace != query?.text.trimmedOfWhitespace else { return }
    await search()
  }

  public func setYours(_ on: Bool) async {
    guard on != yours else { return }
    yours = on
    await search()
  }

  /// The list again, for the camera and the view the map shows now, typed or not.
  public func searchThisArea() async {
    await search(inView: true)
  }

  /// A place row: the camera moves to the place — its footprint where the geocoder gave one — and
  /// the list becomes the sites nearest there.
  public func pick(_ place: PlaceSearchItem) async {
    let result = place.place
    var bounds: LatLonBounds?
    if let south = result.bboxSouth, let north = result.bboxNorth, let west = result.bboxWest,
      let east = result.bboxEast
    {
      bounds = LatLonBounds(south: south, north: north, west: west, east: east)
    }
    move(
      to: SiteFinderOpening(points: [
        MapPoint(
          name: result.location, latitude: result.latitude, longitude: result.longitude,
          bounds: bounds)
      ]))
    text = ""
    await search()
  }

  /// Moves the camera to the phone's position and lists the sites around it.
  public func useMyLocation() async {
    isLocating = true
    locationFailure = nil
    let here: DeviceLocation
    do {
      here = try await locator.currentLocation()
    } catch {
      isLocating = false
      locationFailure = error
      return
    }
    isLocating = false
    move(to: .point(here))
    await search()
  }

  /// The point the diver touched, or nothing where the map has no such site.
  public func select(_ uuid: UUID) {
    selected = points.point(uuid)
  }

  /// The next page, once `row` is the last shown.
  public func loadMore(after row: DiveSiteSearchRow) async {
    guard row.id == rows.last?.id, let list else { return }
    await list.loadMore()
  }

  /// Reads again what a route can mend, each time one appears, until the calling task is
  /// cancelled.
  public func followRoute() async {
    await session.connectivity.eachRouteAppearance {
      if let list { await list.rereadIfStale() }
      await points.load()
    }
  }

  // MARK: - Requests

  private func move(to place: SiteFinderOpening) {
    camera = place.camera(width: viewport.width, height: viewport.height)
    restsOnWorld = false
    restsOnOpening = false
  }

  /// `inView` narrows a typed search to the view as well, which an untyped one always is.
  private func search(inView: Bool = false) async {
    let narrowed = inView || text.trimmedOfWhitespace.isEmpty
    let query = DiveSiteSearchQuery(
      text: text,
      camera: restsOnWorld
        ? nil : DeviceLocation(latitude: camera.latitude, longitude: camera.longitude),
      box: narrowed ? shownBox : nil, until: form?.values.startTime, yours: yours)
    self.query = query
    offersSearchThisArea = false
    let list = PagedList<DiveSiteSearchRow>(
      session: session, itemsPerPage: APIClient.searchPageSize, cache: cacheKey(query),
      routed: true
    ) { client, page, itemsPerPage in
      try await client.searchDiveSites(query, page: page, itemsPerPage: itemsPerPage).listPage
    }
    self.list = list
    await list.load()
  }

  /// What the diver sees of the map, where there is a map, measured, off the world the opening
  /// rests on; never under *Your sites*, whose list the server does not narrow.
  private var shownBox: LatLonBounds? {
    guard hasMap, Self.isMeasured(viewport), !restsOnWorld, !yours else { return nil }
    return camera.bounds(width: viewport.width, height: viewport.height)
  }

  private static func isMeasured(_ size: (width: Double, height: Double)) -> Bool {
    size.width > 0 && size.height > 0
  }

  /// The Sites tab keeps its untyped lists, so the tab shows the last one at once and offline;
  /// the dive form's picker lists the cached lookup rows offline instead, and a typed search is
  /// never kept.
  private func cacheKey(_ query: DiveSiteSearchQuery) -> PageCacheKey<DiveSiteSearchRow>? {
    guard host == .sitesTab, query.text.trimmedOfWhitespace.isEmpty else { return nil }
    return .siteFinder(yours: query.yours)
  }
}
