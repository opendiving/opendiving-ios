import Foundation
import Observation

/// A settings list a server may not have: a read whose 404 means the feature is absent there —
/// an API older than it, or one where it does not apply — and the block showing it is left
/// out, rather than reporting an error. Any other failure keeps what was already read and says
/// why. The read is direct and needs a route: with none it fails at once with the
/// no-connection sentence, and ``followRoute()`` reads again once one appears.
///
/// A list made with a ``KeptSetting`` shows the phone's copy at once while it is read, and keeps
/// it standing under ``lastUpdated`` when the read fails; a 404 forgets it.
@MainActor
@Observable
public final class OptionalList<Value: Sendable> {
  /// Nil until a read lands, and again once the server has said it has no such list.
  public private(set) var value: Value?
  /// The server answered the read with 404: the block is left out.
  public private(set) var isAbsent = false
  /// Why the last read failed, until one lands.
  public private(set) var failure: String?
  /// When the phone's copy on screen was fetched, until a read lands in its place: the line
  /// saying how old it is stands while that read is on its way, and through one that fails.
  public var lastUpdated: Date? { fetchedAt }
  /// When the cache's copy on screen was fetched; nil once a read has landed.
  private var fetchedAt: Date?

  @ObservationIgnored private let session: Session
  @ObservationIgnored private let read: @Sendable (APIClient) async throws -> Value
  /// Writes a value to the cache, fetched when the date says; nil for a list that is not kept.
  @ObservationIgnored private var keep: ((AccountCache, Value, Date) -> Void)?
  @ObservationIgnored private var forget: ((AccountCache) -> Void)?

  public init(session: Session, read: @escaping @Sendable (APIClient) async throws -> Value) {
    self.session = session
    self.read = read
  }

  /// A list kept under `setting`, shown from the phone's copy until its read lands.
  public convenience init(
    session: Session, kept setting: KeptSetting,
    read: @escaping @Sendable (APIClient) async throws -> Value
  ) where Value: Codable {
    self.init(session: session, read: read)
    keep = { cache, value, fetchedAt in cache.writeKept(value, setting, fetchedAt: fetchedAt) }
    forget = { cache in cache.removeKept(setting) }
    if let entry = AccountStores.current(session)?.cache.kept(setting, of: Value.self) {
      value = entry.value
      fetchedAt = entry.fetchedAt
    }
  }

  public func load() async {
    let stores = AccountStores.current(session)
    do {
      let client = try session.routedClient()
      let read = read
      let value = try await read(client)
      self.value = value
      fetchedAt = nil
      isAbsent = false
      failure = nil
      if let keep, let cache = cacheForAnswer(fetchedUnder: stores, session: session) {
        keep(cache, value, Date())
      }
    } catch is CancellationError {
    } catch {
      let error = APIError(error)
      if case .http(status: 404, _) = error {
        value = nil
        fetchedAt = nil
        isAbsent = true
        failure = nil
        if let forget, let cache = cacheForAnswer(fetchedUnder: stores, session: session) {
          forget(cache)
        }
      } else {
        failure = error.message
      }
    }
  }

  /// Reads again each time a route appears, until the calling task is cancelled.
  public func followRoute() async {
    await session.connectivity.eachRouteAppearance { await load() }
  }

  /// Reads again each time a route appears or the app returns to the foreground, until the
  /// calling task is cancelled: for a list whose rows change elsewhere while the screen shows,
  /// as a key's last use does.
  public func followRouteAndForeground() async {
    for await _ in session.connectivity.moments() { await load() }
  }

  /// Changes what was read in place — a rename, a row added from a write's answer — without
  /// reading again. Nothing happens before there is a value. A kept copy keeps the date it was
  /// fetched, since the change is laid over it rather than read with it.
  public func update(_ change: (Value) -> Value) {
    guard let value else { return }
    let changed = change(value)
    self.value = changed
    if let keep, let cache = cacheForAnswer(fetchedUnder: nil, session: session) {
      keep(cache, changed, fetchedAt ?? Date())
    }
  }
}
