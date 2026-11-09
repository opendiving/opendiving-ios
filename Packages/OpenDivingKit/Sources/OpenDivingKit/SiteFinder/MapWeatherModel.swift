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

  /// The centre of the map, to a tenth of a degree.
  public struct Cell: Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double
  }

  @ObservationIgnored private let session: Session
  /// How long the map rests on a cell before it is asked about.
  @ObservationIgnored var settleDelay = Duration.milliseconds(600)
  @ObservationIgnored var now: @Sendable () -> Date = { Date() }
  @ObservationIgnored private var held: [Cell: (at: Date, read: DiveConditionsCurrentRead)] = [:]
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
    shown = cell
    if session.state.origin != origin {
      origin = session.state.origin
      held = [:]
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
