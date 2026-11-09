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
/// **Untyped, the list is the sites in view.** The opening, a picked place and *Your sites*
/// toggled each send the part of the map the diver sees as a box. A typed search looks
/// everywhere, nearest the camera first.
///
/// **The list follows the camera.** Once a pan or *Use my location* has moved it and it has
/// rested for ``settleDelay``, the list is asked for again for the view, a typed search narrowed
/// to it too; a later move cancels a request still on its way. A request the server would read as
/// the last one answered for the same *Your sites* setting is not sent again: that list shows.
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
  /// A request is on its way; the list shows what it showed until the answer lands.
  public private(set) var isSearching = false
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
  /// How long the camera rests before the list follows it.
  @ObservationIgnored var settleDelay = Duration.milliseconds(300)
  /// The wait for the camera to rest.
  @ObservationIgnored private(set) var settling: Task<Void, Never>?
  @ObservationIgnored private var searching: Task<Void, Never>?
  /// Counts requests, so only the latest one's answer is shown.
  @ObservationIgnored private var generation = 0
  /// The last list answered for each *Your sites* setting, and what it asked.
  @ObservationIgnored private var answered: [Bool: Answer] = [:]
  /// The *Your sites* setting the list shown was asked with.
  @ObservationIgnored private var shownYours: Bool?

  private typealias Answer = (query: DiveSiteSearchQuery, list: PagedList<DiveSiteSearchRow>)

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
  /// the camera it opened on.
  public func open() async {
    guard isOpening, !isResolving else { return }
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
    shownYours = false
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
    settle()
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

  /// Moves the camera to the phone's position, where the list follows it as it follows a pan;
  /// with no map, which has no view to follow, the list is the sites around it at once.
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
    if hasMap { settle() } else { await search() }
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

  /// The camera moved: a request still on its way is for a view no longer shown, and the list
  /// follows the camera once it has rested.
  private func settle() {
    settling?.cancel()
    searching?.cancel()
    generation += 1
    settling = Task { [weak self, settleDelay] in
      try? await Task.sleep(for: settleDelay)
      guard !Task.isCancelled, let self else { return }
      settling = nil
      await search(inView: true)
    }
  }

  /// `inView` narrows a typed search to the view as well, which an untyped one always is.
  ///
  /// A list already showing rows for the same setting stays until the new one has its answer,
  /// so the kept pages a new list shows first never flash in its place.
  private func search(inView: Bool = false) async {
    settling?.cancel()
    settling = nil
    searching?.cancel()
    generation += 1
    let generation = generation
    let narrowed = inView || text.trimmedOfWhitespace.isEmpty
    let query = DiveSiteSearchQuery(
      text: text,
      camera: restsOnWorld
        ? nil : DeviceLocation(latitude: camera.latitude, longitude: camera.longitude),
      box: narrowed ? shownBox : nil, until: form?.values.startTime, yours: yours)
    self.query = query
    if let last = answered[query.yours], last.query.items == query.items,
      last.list.phase == .loaded, last.list.lastUpdated == nil
    {
      searching = nil
      isSearching = false
      list = last.list
      shownYours = query.yours
      return
    }
    let list = PagedList<DiveSiteSearchRow>(
      session: session, itemsPerPage: APIClient.searchPageSize, cache: cacheKey(query),
      routed: true
    ) { client, page, itemsPerPage in
      try await client.searchDiveSites(query, page: page, itemsPerPage: itemsPerPage).listPage
    }
    if self.list?.phase != .loaded || shownYours != query.yours {
      self.list = list
      shownYours = query.yours
    }
    isSearching = true
    let task = Task { [weak self] in
      await list.load()
      guard let self, generation == self.generation else { return }
      self.list = list
      shownYours = query.yours
      answered[query.yours] = (query, list)
      searching = nil
      isSearching = false
    }
    searching = task
    await task.value
  }

  /// What the diver sees of the map, where there is a map, measured, off the world the opening
  /// rests on.
  private var shownBox: LatLonBounds? {
    guard hasMap, Self.isMeasured(viewport), !restsOnWorld else { return nil }
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
