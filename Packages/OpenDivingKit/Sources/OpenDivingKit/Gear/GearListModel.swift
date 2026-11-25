import Foundation
import Observation

/// More's *Gear*: the diver's gear, archived items among them, every page of it since the page
/// files it under the Type picker's headings, and below it their gear sets a page at a time, each
/// over the account's copy of the pages it has shown. With no route nothing is asked for, and
/// each list reads again once one appears.
@MainActor
@Observable
public final class GearListModel {
  public let items: PagedList<GearItemRead>
  public let sets: PagedList<GearSetRead>

  @ObservationIgnored private let session: Session

  public init(session: Session) {
    self.session = session
    items = PagedList(session: session, cache: .gearItems, routed: true, readsEveryPage: true) {
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

  /// The gear shown, filed under the Type picker's headings.
  public var sections: [GearTypeSection] { GearTypeSection.sections(items.items) }

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
    let account = AccountReload(session: session)
    async let gear: Void = items.refresh(sharing: account)
    async let sets: Void = self.sets.refresh(sharing: account)
    _ = await (gear, sets)
  }

  private func reread() async {
    async let gear: Void = items.rereadIfStale()
    async let sets: Void = self.sets.rereadIfStale()
    _ = await (gear, sets)
  }
}
