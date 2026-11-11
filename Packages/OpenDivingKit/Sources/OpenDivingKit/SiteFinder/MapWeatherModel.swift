import Foundation
import Observation

/// The weather at a dive site on the Sites map, for its weather bar: the one the finder picks,
/// ``SiteFinderModel/weatherSite``; with none the bar is empty.
///
/// Only a site's pin is asked about, never the map's centre: divers look at the same sites, so
/// the instance's provider budget, shared by every account, buys answers its cache shares between
/// them rather than one per pan. A pin is asked about as the server rounds it, to two decimals,
/// about a kilometre. An answer is kept for a quarter of an hour and stands for every site within
/// ``reuseRadius`` of it, which the provider's models, a few kilometres to a cell, tell apart no
/// better: a drag that brings another site of the same bay nearest the middle asks nothing, and the
/// bar keeps what it shows until another site's own answer replaces it.
@MainActor
@Observable
public final class MapWeatherModel {
  /// The answer the bar shows; nil while there is none to show.
  public private(set) var current: DiveConditionsCurrentRead? {
    didSet { if current != nil { isUnreachable = false } }
  }

  /// The site ``current`` is shown for, as it was titled then: while another site's answer is on
  /// its way, the last one's, so the card never puts one site's name over another's weather.
  public private(set) var site: SiteFinderModel.WeatherSite?

  /// Whether the shown pin has no weather because the server could not be reached, which the
  /// bar says in place of the weather.
  public private(set) var isUnreachable = false

  /// A site's pin as the server rounds it, to two decimals.
  public struct Cell: Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double
  }

  @ObservationIgnored private let session: Session
  /// How long a site stays open before its pin is asked about, so hopping from site to site asks
  /// only of the one it lands on.
  @ObservationIgnored var settleDelay = Duration.milliseconds(300)
  /// How long a cell whose ask failed waits to be asked again, doubling to ``longestPause``.
  @ObservationIgnored var retryDelay = Duration.seconds(15)
  static let longestPause = Duration.seconds(300)
  @ObservationIgnored var now: @Sendable () -> Date = { Date() }
  @ObservationIgnored private var held: [Cell: (at: Date, read: DiveConditionsCurrentRead)] = [:]
  @ObservationIgnored private var shown: Cell?
  /// The waits between asks, which a route appearing ends.
  @ObservationIgnored private var waits: [UUID: AsyncStream<Never>.Continuation] = [:]
  /// The server the answers are from, and whether it fetches no conditions at all.
  @ObservationIgnored private var origin: ServerOrigin?
  @ObservationIgnored private var isOff = false

  static let freshFor: TimeInterval = 15 * 60
  /// How near, in metres, a held answer stands for a site.
  static let reuseRadius = 2_000.0

  public init(session: Session) {
    self.session = session
  }

  /// The cell a site's pin is asked about in.
  public static func cell(_ pin: DeviceLocation) -> Cell {
    Cell(
      latitude: NumberText.round(pin.latitude * 100) / 100,
      longitude: NumberText.round(WebMercator.wrap(longitude: pin.longitude) * 100) / 100)
  }

  /// Shows the weather at `site`, or nothing for nil: a held answer within ``reuseRadius`` at
  /// once, else, once the site has stayed picked, the server's, asking until it answers: a failed
  /// ask waits ``retryDelay``, doubling, or until a route appears, and asks again. Ends once
  /// another site is shown or the calling task is cancelled, as picking another site does.
  public func show(_ site: SiteFinderModel.WeatherSite?) async {
    let cell = site.map { Self.cell($0.pin) }
    shown = cell
    if session.state.origin != origin {
      origin = session.state.origin
      held = [:]
      isOff = false
    }
    guard !isOff, let site, let cell else {
      current = nil
      self.site = nil
      isUnreachable = false
      return
    }
    if let near = heldAnswer(near: site.pin) {
      current = near
      self.site = site
      return
    }
    try? await Task.sleep(for: settleDelay)
    var pause = retryDelay
    while isShown(cell) {
      let appearances = session.connectivity.routeAppearances
      guard await !ask(cell, for: site) else { return }
      // A route that appeared while the ask was out is a reason to ask again now.
      guard session.connectivity.routeAppearances == appearances else { continue }
      await wait(pause)
      pause = min(pause * 2, Self.longestPause)
    }
  }

  /// The freshest-held answer nearest `pin`, within ``reuseRadius``.
  private func heldAnswer(near pin: DeviceLocation) -> DiveConditionsCurrentRead? {
    let now = now()
    return
      held
      .filter { now.timeIntervalSince($0.value.at) < Self.freshFor }
      .map { cell, kept in
        (
          kept.read,
          GeoDistance.haversineMeters(
            fromLatitude: pin.latitude, longitude: pin.longitude, toLatitude: cell.latitude,
            longitude: cell.longitude)
        )
      }
      .filter { $0.1 <= Self.reuseRadius }
      .min { $0.1 < $1.1 }?.0
  }

  /// Asks the server about `cell` once, for `site`; false when it is worth asking again.
  private func ask(_ cell: Cell, for site: SiteFinderModel.WeatherSite) async -> Bool {
    // Another cell's weather would be wrong here, and there is none to show for this one.
    let client: APIClient
    do {
      client = try session.routedClient()
    } catch {
      return failed(error)
    }
    let read: DiveConditionsCurrentRead?
    do {
      read = try await client.currentConditions(
        latitude: cell.latitude, longitude: cell.longitude)
    } catch {
      return isShown(cell) ? failed(error) : true
    }
    guard let read else {
      isOff = true
      current = nil
      self.site = nil
      isUnreachable = false
      return true
    }
    held[cell] = (now(), read)
    if isShown(cell) {
      current = read
      self.site = site
    }
    return true
  }

  /// Empties the bar for a failed ask; false unless the session is over, which no retry mends.
  private func failed(_ error: any Error) -> Bool {
    let error = APIError(error)
    current = nil
    site = nil
    isUnreachable = error.isUnreachable
    return error == .signedOut
  }

  /// Waits `pause`, or until a route appears or the calling task is cancelled.
  private func wait(_ pause: Duration) async {
    let id = UUID()
    let (ended, wake) = AsyncStream<Never>.makeStream()
    waits[id] = wake
    defer { waits[id] = nil }
    await withTaskGroup(of: Void.self) { group in
      group.addTask { try? await Task.sleep(for: pause) }
      group.addTask { for await _ in ended {} }
      await group.next()
      group.cancelAll()
    }
  }

  private func isShown(_ cell: Cell) -> Bool {
    !Task.isCancelled && shown == cell
  }

  /// Ends the wait of a cell whose ask failed each time a route appears, until the calling task
  /// is cancelled, so the bar fills as soon as the server can be reached again.
  public func followRoute() async {
    await session.connectivity.eachRouteAppearance { routeAppeared() }
  }

  func routeAppeared() {
    for wake in waits.values { wake.finish() }
  }
}
