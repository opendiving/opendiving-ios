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
  public private(set) var current: DiveConditionsCurrentRead? {
    didSet { if current != nil { isUnreachable = false } }
  }

  /// Whether the shown cell has no weather because the server could not be reached, which the
  /// bar says in place of the weather.
  public private(set) var isUnreachable = false

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
  /// How long a cell whose ask failed waits to be asked again, doubling to ``longestPause``.
  @ObservationIgnored var retryDelay = Duration.seconds(15)
  static let longestPause = Duration.seconds(300)
  @ObservationIgnored var now: @Sendable () -> Date = { Date() }
  @ObservationIgnored private var held: [Cell: (at: Date, read: DiveConditionsCurrentRead)] = [:]
  @ObservationIgnored private var places: [Cell: Place] = [:]
  @ObservationIgnored private var shown: Cell?
  /// The waits between asks, which a route appearing ends.
  @ObservationIgnored private var waits: [UUID: AsyncStream<Never>.Continuation] = [:]
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
  /// the server, asking until it answers: a failed ask waits ``retryDelay``, doubling, or until a
  /// route appears, and asks again. Ends once the map no longer shows `cell` or the calling task
  /// is cancelled, as a pan onward does.
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
      isUnreachable = false
      return
    }
    if let kept = held[cell], now().timeIntervalSince(kept.at) < Self.freshFor {
      current = kept.read
      return
    }
    try? await Task.sleep(for: settleDelay)
    var pause = retryDelay
    while isShown(cell) {
      let appearances = session.connectivity.routeAppearances
      guard await !ask(cell) else { return }
      // A route that appeared while the ask was out is a reason to ask again now.
      guard session.connectivity.routeAppearances == appearances else { continue }
      await wait(pause)
      pause = min(pause * 2, Self.longestPause)
    }
  }

  /// Asks the server about `cell` once; false when it is worth asking again.
  private func ask(_ cell: Cell) async -> Bool {
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
      isUnreachable = false
      return true
    }
    held[cell] = (now(), read)
    if isShown(cell) { current = read }
    return true
  }

  /// Empties the bar for a failed ask; false unless the session is over, which no retry mends.
  private func failed(_ error: any Error) -> Bool {
    let error = APIError(error)
    current = nil
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

  /// Ends the wait of a cell whose ask failed each time a route appears, until the calling task
  /// is cancelled, so the bar fills as soon as the server can be reached again.
  public func followRoute() async {
    await session.connectivity.eachRouteAppearance { routeAppeared() }
  }

  func routeAppeared() {
    for wake in waits.values { wake.finish() }
  }
}
