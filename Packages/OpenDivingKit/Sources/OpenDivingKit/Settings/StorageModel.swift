import Foundation
import Observation

/// *Data*'s storage: what the account's uploads take up, from the phone's copy at once and then
/// the server, read each time the screen shows and each time a route appears. A read that fails
/// leaves the copy standing, under ``lastUpdated``.
@MainActor
@Observable
public final class StorageModel {
  /// Nil until the phone has a copy or the first read lands.
  public private(set) var usage: StorageUsageRead?
  /// Why the last read failed, shown while there is no usage to show.
  public private(set) var loadFailure: String?
  /// When the phone's copy on screen was fetched, until a read lands in its place: the line
  /// saying how old it is stands while that read is on its way, and through one that fails.
  public var lastUpdated: Date? { fetchedAt }
  /// When the cache's copy on screen was fetched; nil once a read has landed.
  private var fetchedAt: Date?

  @ObservationIgnored private let session: Session

  public init(session: Session) {
    self.session = session
    if let entry = AccountStores.current(session)?.cache.kept(.storage, of: StorageUsageRead.self) {
      usage = entry.value
      fetchedAt = entry.fetchedAt
    }
  }

  /// `GET /user/storage`. With no route nothing is asked for: a usage already shown stays.
  public func load() async {
    let stores = AccountStores.current(session)
    do {
      let usage = try await session.routedClient().storage()
      self.usage = usage
      fetchedAt = nil
      loadFailure = nil
      cacheForAnswer(fetchedUnder: stores, session: session)?.writeKept(usage, .storage)
    } catch is CancellationError {
    } catch {
      loadFailure = APIError(error).message
    }
  }

  /// Reads again each time a route appears, until the calling task is cancelled.
  public func followRoute() async {
    await session.connectivity.eachRouteAppearance { await load() }
  }
}
