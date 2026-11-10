import Foundation
import Observation

/// A gear item's page: the item, and the dives it was used on a page at a time. Each shows at
/// once from the account's copy where the phone has shown it, and with no route nothing is
/// asked for until one appears.
@MainActor
@Observable
public final class GearItemDetailModel {
  public let page: RecordPage<GearItemRead>
  public let dives: PagedList<DiveListItem>

  @ObservationIgnored private let session: Session
  @ObservationIgnored private var appearancesAtLoad = 0

  public init(session: Session, gearItemUUID: UUID) {
    self.session = session
    page = RecordPage(session: session, gearItem: gearItemUUID)
    dives = PagedList(
      session: session, itemsPerPage: APIClient.nestedListPageSize,
      cache: .gearItemDives(gearItemUUID), routed: true
    ) { client, page, itemsPerPage in
      try await client.dives(.gearItem(gearItemUUID), page: page, itemsPerPage: itemsPerPage)
    }
  }

  /// The item, then its dives; on a return, whatever shows only the phone's copy, again.
  public func load() async {
    appearancesAtLoad = session.connectivity.routeAppearances
    await page.load()
    if page.phase.isLoaded { await dives.rereadIfStale() }
  }

  /// Pull-to-refresh. An item already on screen stays there when the refresh fails.
  public func refresh() async {
    await page.refresh()
    if page.phase.isLoaded { await dives.refresh() }
  }

  /// Reads again what a route can mend, each time one appears, until the calling task is
  /// cancelled.
  public func followRoute() async {
    if session.connectivity.routeAppearances != appearancesAtLoad { await reread() }
    await session.connectivity.eachRouteAppearance { await reread() }
  }

  private func reread() async {
    await page.reread()
    if page.phase.isLoaded { await dives.rereadIfStale() }
  }

  /// The write archiving `item`, or bringing it back.
  nonisolated public static func archiveToggle(_ item: GearItemRead) -> OutboxOperation {
    .updateGearItem(.server(item.uuid), GearItemUpdate(archived: !item.isArchived))
  }

  /// Whether the delete offers *Archive instead*: not for gear archived already, which the
  /// toggle would bring back instead.
  nonisolated public static func offersArchiveInstead(_ item: GearItemRead) -> Bool {
    !item.isArchived
  }

  /// Queues `operation`, an archive or a delete from the page; the reason it could not, where
  /// the outbox refused it.
  public static func queue(_ operation: OutboxOperation, in outbox: OutboxModel) -> String? {
    do {
      try outbox.queue(operation)
      return nil
    } catch {
      return RecordSheetModel<GearItemFormValues>.sentence(error)
    }
  }
}
