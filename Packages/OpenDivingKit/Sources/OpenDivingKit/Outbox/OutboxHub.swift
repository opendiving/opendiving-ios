import Foundation

/// Something that shows what an account's stores hold and reads them again when they change.
@MainActor
protocol AccountStoresObserver: AnyObject {
  func accountStoresChanged()
}

/// What the process holds for one account's outbox, however many models it builds over it:
/// the one flush, the answers counted against each item, and who to tell when the stores
/// change. Two flushes would send one item twice, so every model asks this for its flush.
@MainActor
final class OutboxHub {
  private static var hubs: [String: OutboxHub] = [:]
  /// Account loads a model started, by server, so a moment during one starts no second.
  private static var loading: [String: Task<Void, Never>] = [:]

  static func hub(for directory: URL) -> OutboxHub {
    let key = directory.standardizedFileURL.path
    if let hub = hubs[key] { return hub }
    let hub = OutboxHub()
    hubs[key] = hub
    return hub
  }

  /// Runs `load` unless one is already running for `key`, and waits for whichever runs.
  static func loadAccount(key: String, _ load: @escaping @MainActor () async -> Void) async {
    if let running = loading[key] {
      await running.value
      return
    }
    let task = Task { @MainActor in await load() }
    loading[key] = task
    await task.value
    loading[key] = nil
  }

  var flush: Task<Void, Never>?
  /// A flush was asked for while one ran: true if any of those asks was *Sync now*.
  var again: Bool?
  /// The item being sent.
  var sending: UUID?
  /// The server's 5xx and 429 answers per item since launch. Twice passes an item over for
  /// the flushes the app's own triggers start.
  var answers: [UUID: Int] = [:]
  /// The items already tried in the flush running, so one that failed is not sent twice in it.
  var tried: Set<UUID> = []
  var lookupsRefresh: Task<Void, Never>?
  var draftsRefresh: Task<Void, Never>?

  private var observers: [WeakObserver] = []

  func observe(_ observer: some AccountStoresObserver) {
    observers.removeAll { $0.value == nil || $0.value === observer }
    observers.append(WeakObserver(value: observer))
  }

  /// Tells every model over this account that its stores changed.
  func changed() {
    observers.removeAll { $0.value == nil }
    for observer in observers { observer.value?.accountStoresChanged() }
  }

  private struct WeakObserver {
    weak var value: (any AccountStoresObserver)?
  }
}
