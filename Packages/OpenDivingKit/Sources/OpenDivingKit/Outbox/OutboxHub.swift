import Foundation

/// Something that shows what an account's stores hold and reads them again when they change.
@MainActor
protocol AccountStoresObserver: AnyObject {
  func accountStoresChanged()
}

/// Something that lists an account's records and fetches the list again when one may have
/// joined it or changed in it.
@MainActor
protocol AccountListsObserver: AnyObject {
  func accountListsChanged()
}

/// What the process holds for one account's outbox, however many models it builds over it:
/// the one flush, the answers counted against each item, and who to tell when the stores or
/// the lists change. Two flushes would send one item twice, so every model asks this for its flush.
@MainActor
final class OutboxHub {
  private static var hubs: [String: OutboxHub] = [:]
  /// Account loads a model started, by session, so a moment during one starts no second.
  private static var loading: [ObjectIdentifier: Task<Void, Never>] = [:]

  static func hub(for directory: URL) -> OutboxHub {
    let key = directory.standardizedFileURL.path
    if let hub = hubs[key] { return hub }
    let hub = OutboxHub()
    hubs[key] = hub
    return hub
  }

  /// Drops what the process holds for the account in `directory`, as a relaunch does.
  static func forget(_ directory: URL) {
    hubs[directory.standardizedFileURL.path] = nil
  }

  /// Runs `load` unless one is already running for `key`, and waits for whichever runs.
  static func loadAccount(key: ObjectIdentifier, _ load: @escaping @MainActor () async -> Void)
    async
  {
    if let running = loading[key] {
      await running.value
      return
    }
    let task = Task { @MainActor in
      await load()
      loading[key] = nil
    }
    loading[key] = task
    await task.value
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
  /// Drafts being changed in a form: their queued writes wait for it to be left or for the
  /// changes to pause, so a flush running meanwhile does not send every keystroke.
  var editing: Set<RecordRef> = []
  var lookupsRefresh: Task<Void, Never>?
  var draftsRefresh: Task<Void, Never>?

  private var observers: [WeakObserver] = []
  private var listObservers: [WeakListObserver] = []

  func observe(_ observer: some AccountStoresObserver) {
    observers.removeAll { $0.value == nil || $0.value === observer }
    observers.append(WeakObserver(value: observer))
  }

  /// Tells every model over this account that its stores changed.
  func changed() {
    observers.removeAll { $0.value == nil }
    for observer in observers { observer.value?.accountStoresChanged() }
  }

  func observeLists(_ observer: some AccountListsObserver) {
    listObservers.removeAll { $0.value == nil || $0.value === observer }
    listObservers.append(WeakListObserver(value: observer))
  }

  /// Tells every list over this account that the server holds records it may not show: an
  /// import applied, a queued write to a listed record landed. Not ``changed()``, which every
  /// send fires and a list would answer with a fetch each.
  func listsChanged() {
    listObservers.removeAll { $0.value == nil }
    for observer in listObservers { observer.value?.accountListsChanged() }
  }

  private struct WeakObserver {
    weak var value: (any AccountStoresObserver)?
  }

  private struct WeakListObserver {
    weak var value: (any AccountListsObserver)?
  }
}
