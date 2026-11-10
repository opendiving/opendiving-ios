import Foundation
import Observation

/// A gear item's service card: its schedules and its service history, each kept for the account
/// as the page's other lists are, and read again when a write lands.
@MainActor
@Observable
public final class GearServiceModel {
  public let gearItemUUID: UUID
  public let schedules: PagedList<GearServiceScheduleRead>
  public let records: PagedList<GearServiceRecordRead>

  @ObservationIgnored private let session: Session

  public init(session: Session, gearItemUUID: UUID) {
    self.session = session
    self.gearItemUUID = gearItemUUID
    schedules = PagedList(
      session: session, itemsPerPage: APIClient.nestedListPageSize,
      cache: .gearServiceSchedules(gearItemUUID), routed: true
    ) { client, page, itemsPerPage in
      try await client.gearServiceSchedules(
        gearItemUUID: gearItemUUID, page: page, itemsPerPage: itemsPerPage)
    }
    records = PagedList(
      session: session, itemsPerPage: APIClient.nestedListPageSize,
      cache: .gearServiceRecords(gearItemUUID), routed: true
    ) { client, page, itemsPerPage in
      try await client.gearServiceRecords(
        gearItemUUID: gearItemUUID, page: page, itemsPerPage: itemsPerPage)
    }
  }

  public func rereadIfStale() async {
    async let schedules: Void = schedules.rereadIfStale()
    async let records: Void = records.rereadIfStale()
    _ = await (schedules, records)
  }

  public func refresh() async {
    async let schedules: Void = schedules.refresh()
    async let records: Void = records.refresh()
    _ = await (schedules, records)
  }

  /// The schedule a form opens over: the card's kept copy, which a form opened offline has, else
  /// the server's.
  public static func schedule(_ uuid: UUID, of gearItem: RecordRef, session: Session)
    async throws -> GearServiceScheduleRead
  {
    if let item = gearItem.serverUUID,
      let kept = kept(PageCacheKey.gearServiceSchedules(item), session)?.first(where: {
        $0.uuid == uuid
      })
    {
      return kept
    }
    return try await session.routedClient().gearServiceSchedule(uuid)
  }

  /// The service a form opens over, as ``schedule(_:of:session:)`` finds a schedule.
  public static func record(_ uuid: UUID, of gearItem: RecordRef, session: Session)
    async throws -> GearServiceRecordRead
  {
    if let item = gearItem.serverUUID,
      let kept = kept(PageCacheKey.gearServiceRecords(item), session)?.first(where: {
        $0.uuid == uuid
      })
    {
      return kept
    }
    return try await session.routedClient().gearServiceRecord(uuid)
  }

  private static func kept<Item>(_ key: PageCacheKey<Item>, _ session: Session) -> [Item]? {
    AccountStores.current(session)?.cache.pages(key.name, of: Item.self)?.value.items
  }
}
