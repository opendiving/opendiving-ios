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
  /// When the usage shown was fetched, once it is the cache's and no read is on its way. A read
  /// that lands replaces it with nothing to say.
  public var lastUpdated: Date? { isReading ? nil : fetchedAt }
  /// When the cache's copy on screen was fetched; nil once a read has landed.
  private var fetchedAt: Date?
  private var isReading = false

  @ObservationIgnored private let session: Session

  public init(session: Session) {
    self.session = session
    if let entry = AccountStores.current(session)?.cache.kept(.storage, of: StorageUsageRead.self) {
      usage = entry.value
      fetchedAt = entry.fetchedAt
      // Its screen reads it at once: until then the copy is not yet behind a failed read.
      isReading = true
    }
  }

  /// `GET /user/storage`. With no route nothing is asked for: a usage already shown stays.
  public func load() async {
    let stores = AccountStores.current(session)
    isReading = true
    defer { isReading = false }
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
