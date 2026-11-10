import Foundation
import Observation

/// More's *Gear*: the diver's gear, archived items among them, and below it their gear sets,
/// each a page at a time over the account's copy of the pages it has shown. With no route
/// nothing is asked for, and each list reads again once one appears.
@MainActor
@Observable
public final class GearListModel {
  public let items: PagedList<GearItemRead>
  public let sets: PagedList<GearSetRead>

  @ObservationIgnored private let session: Session

  public init(session: Session) {
    self.session = session
    items = PagedList(session: session, cache: .gearItems, routed: true) {
      client, page, itemsPerPage in
      // Every item, archived ones badged: with no switch, an item left out could never be
      // brought back.
      try await client.gearItems(page: page, itemsPerPage: itemsPerPage, includeArchived: true)
    }
    sets = PagedList(session: session, cache: .gearSets, routed: true) {
      client, page, itemsPerPage in
      try await client.gearSets(page: page, itemsPerPage: itemsPerPage)
    }
  }

  /// Both lists, or both again on a return where they show only the phone's copy, then each
  /// read again as a route appears, until the calling task is cancelled.
  public func show() async {
    let seen = session.connectivity.routeAppearances
    await reread()
    // A route that appeared while the reads were skipped has no moment left to wait for.
    if session.connectivity.routeAppearances != seen { await reread() }
    await session.connectivity.eachRouteAppearance { await reread() }
  }

  /// Pull-to-refresh: both lists from their first page.
  public func refresh() async {
    async let gear: Void = items.refresh()
    async let sets: Void = self.sets.refresh()
    _ = await (gear, sets)
  }

  private func reread() async {
    async let gear: Void = items.rereadIfStale()
    async let sets: Void = self.sets.rereadIfStale()
    _ = await (gear, sets)
  }
}
