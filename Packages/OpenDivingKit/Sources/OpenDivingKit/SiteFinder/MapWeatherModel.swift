import Foundation
import Observation

/// The weather at the centre of the Sites map, for its weather bar.
///
/// Asked for by cell rather than by point: the centre rounded to a tenth of a degree, about
/// 11 km, so a pan inside a bay asks nothing and the instance's provider budget, shared by every
/// account, goes on places rather than on pixels. An answer is kept for a quarter of an hour,
/// so panning back costs nothing either. Zoomed out past a region the centre names no weather
/// anyone would act on, and the bar is empty.
@MainActor
@Observable
public final class MapWeatherModel {
  /// About a region's width on a phone: wider than this, the bar shows nothing.
  public static let minZoom = 6.0

  /// The answer for the cell the map was last shown at; nil while there is none to show.
  public private(set) var current: DiveConditionsCurrentRead?

  /// Where the shown weather is, once the bar has been tapped: nil while it is looked up.
  public private(set) var place: Place?

  /// The centre of the map, to a tenth of a degree.
  public struct Cell: Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double
  }

  /// A cell named as the geocoder names the place it is in, or by its position where it has no
  /// name or none could be asked for.
  public struct Place: Hashable, Sendable {
    public let title: String
    /// What the geocoder's licence asks to be shown with the name.
    public let credit: String?

    public init(title: String, credit: String?) {
      self.title = title
      self.credit = credit
    }
  }

  @ObservationIgnored private let session: Session
  /// How long the map rests on a cell before it is asked about.
  @ObservationIgnored var settleDelay = Duration.milliseconds(600)
  @ObservationIgnored var now: @Sendable () -> Date = { Date() }
  @ObservationIgnored private var held: [Cell: (at: Date, read: DiveConditionsCurrentRead)] = [:]
  @ObservationIgnored private var places: [Cell: Place] = [:]
  /// The cell the map last showed, which a route appearing asks about again.
  @ObservationIgnored private var shown: Cell?
  /// The server the answers are from, and whether it fetches no conditions at all.
  @ObservationIgnored private var origin: ServerOrigin?
  @ObservationIgnored private var isOff = false

  static let freshFor: TimeInterval = 15 * 60

  public init(session: Session) {
    self.session = session
  }

  /// The cell a camera looks at, or nil zoomed out past ``minZoom``.
  public static func cell(_ camera: MapCamera) -> Cell? {
    guard camera.zoom >= minZoom else { return nil }
    return Cell(
      latitude: NumberText.round(camera.latitude * 10) / 10,
      longitude: NumberText.round(WebMercator.wrap(longitude: camera.longitude) * 10) / 10)
  }

  /// Shows the weather at `cell`, from what is held or, once the map has rested there, from
  /// the server. An answer lands only while the map still shows `cell`: a pan onward cancels the
  /// task that asked, but not one a route appearing started.
  public func show(_ cell: Cell?) async {
    if cell != shown { place = nil }
    shown = cell
    if session.state.origin != origin {
      origin = session.state.origin
      held = [:]
      places = [:]
      isOff = false
    }
    guard !isOff, let cell else {
      current = nil
      return
    }
    if let kept = held[cell], now().timeIntervalSince(kept.at) < Self.freshFor {
      current = kept.read
      return
    }
    try? await Task.sleep(for: settleDelay)
    guard isShown(cell) else { return }
    // Another cell's weather would be wrong here, and there is none to show for this one.
    guard let client = try? session.routedClient() else {
      current = nil
      return
    }
    let read: DiveConditionsCurrentRead?
    do {
      read = try await client.currentConditions(
        latitude: cell.latitude, longitude: cell.longitude)
    } catch {
      if isShown(cell) { current = nil }
      return
    }
    guard let read else {
      isOff = true
      current = nil
      return
    }
    held[cell] = (now(), read)
    if isShown(cell) { current = read }
  }

  private func isShown(_ cell: Cell) -> Bool {
    !Task.isCancelled && shown == cell
  }

  /// Names the place the shown cell is in. Asked only when the bar is tapped, since a pan would
  /// otherwise cost the geocoder a request too; a name, or the lack of one, is kept per cell.
  public func lookUpPlace() async {
    guard let cell = shown else { return }
    if let known = places[cell] {
      place = known
      return
    }
    place = nil
    let position = Place(
      title: CoordinateFormat.format(latitude: cell.latitude, longitude: cell.longitude) ?? "",
      credit: nil)
    let found: Place
    switch try? await session.routedClient().geocodeReverse(
      latitude: cell.latitude, longitude: cell.longitude)
    {
    case .named(let result)?:
      found = Place(title: result.location, credit: result.attribution)
      places[cell] = found
    case .nameless?:
      found = position
      places[cell] = found
    case .unknown?, nil:
      found = position
    }
    if shown == cell { place = found }
  }

  /// Asks about the cell the map shows each time a route appears, until the calling task is
  /// cancelled: a pan with no route left the bar empty.
  public func followRoute() async {
    await session.connectivity.eachRouteAppearance { await routeAppeared() }
  }

  func routeAppeared() async {
    guard current == nil else { return }
    await show(shown)
  }
}
