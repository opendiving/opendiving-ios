import Foundation
import Observation

/// The profile's head: the logbook's totals and the places the diver's trips went, from the
/// phone's copy at once and then the server. A read that fails leaves the copy standing, and
/// places that cannot be read are none, so the head draws the world. With no route nothing is
/// asked for, and ``followRoute()`` reads again once one appears.
@MainActor
@Observable
public final class ProfileModel {
  public private(set) var stats: UserDiveStatsRead?
  public private(set) var places: [LocationRead]?

  @ObservationIgnored private let session: Session

  public init(session: Session) {
    self.session = session
    let cache = AccountStores.current(session)?.cache
    stats = cache?.diveStats?.value
    places = cache?.tripPlaces?.value
  }

  public func hero(today: CalendarDate) -> HeroContent {
    ProfileSummary.hero(
      name: session.user?.name ?? "", stats: stats, places: places, units: session.units,
      today: today)
  }

  public func refresh() async {
    guard let client = try? session.routedClient() else { return }
    let stores = AccountStores.current(session)
    async let readStats = try? client.diveStats()
    async let readPlaces = try? client.tripPlaces()
    let (stats, places) = await (readStats, readPlaces)
    let cache = cacheForAnswer(fetchedUnder: stores, session: session)
    if let stats {
      self.stats = stats
      cache?.writeDiveStats(stats)
    }
    if let places {
      self.places = places
      cache?.writeTripPlaces(places)
    } else if self.places == nil {
      self.places = []
    }
  }

  /// Reads again each time a route appears, until the calling task is cancelled.
  public func followRoute() async {
    await session.connectivity.eachRouteAppearance { await refresh() }
  }
}
