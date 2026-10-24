import Foundation
import Observation

/// The queue of writes the server has not acknowledged, for the account the session names —
/// what the form, the record sheets, the pending screen and the app's lifecycle all queue to
/// and flush. Any number may be built over one account's outbox; they share one flush.
///
/// **When it flushes.** Only once the account has loaded in this process
/// (``Session/accountLoaded``): before that the stores are the last account's and the token
/// may be another's. Then on the load itself (``sessionChanged()``), on an item queued — a
/// draft's update waiting for the form to be left or a quiet interval — on a connectivity
/// moment (``handle(_:)``), and on *Sync now* (``syncNow()``). A moment or *Sync now* arriving
/// before the account has loaded runs the account load first, through the loader it was given,
/// and flushes on its success.
///
/// **How it flushes.** Oldest first, inside a background assertion. An item waits for every
/// record it names that the queue still has to create and for every earlier write to its own
/// record. A failure is transient — no route, a timeout, a 5xx, a 429, a create's 409 — and
/// leaves the item pending with its answer; permanent — any other 4xx — and fails it, holding
/// what depends on it; or landed but unreadable, which is done. An item the server answered
/// with a 5xx or a 429 twice is passed over by every flush but *Sync now* and the first after a
/// launch.
@MainActor
@Observable
public final class OutboxModel: AccountStoresObserver {
  public enum OutboxError: Error, Hashable, Sendable {
    /// No account's stores to write to: no server, or signed in before any account loaded.
    case noAccount
    /// The item cannot be edited, or not into that operation.
    case notEditable
    /// A draft's writes go through the draft methods, which coalesce them.
    case draftOperation
  }

  /// The readable items, in queue order.
  public private(set) var items: [OutboxItem] = []
  /// The item files this build cannot read, by name; *Discard* is all they offer.
  public private(set) var unreadable: [String] = []
  /// What the pending screen says once about writes that are done.
  public private(set) var notices: [OutboxNotice] = []
  /// The account's dive drafts: the server's as last read and the phone's own, the most
  /// recently changed first, none whose log or discard is queued.
  public private(set) var drafts: [DiveDraftEntry] = []
  /// The item being sent now.
  public private(set) var sending: UUID?
  public private(set) var isFlushing = false
  /// Whose stores these are; nil when there are none.
  public private(set) var account: UUID?

  @ObservationIgnored let session: Session
  @ObservationIgnored let loadAccount: (@MainActor () async -> Void)?
  @ObservationIgnored let quietInterval: Duration
  @ObservationIgnored var quietTask: Task<Void, Never>?
  @ObservationIgnored var loadTask: Task<Void, Never>?

  /// `loadAccount` is the account load a moment or *Sync now* runs while none has returned in
  /// this process — the app hands its loader's quiet entry, which raises no alert; without
  /// one the session's own load runs. `quietInterval` is how long a draft's update waits for
  /// the next change before it is sent.
  public init(
    session: Session, loadAccount: (@MainActor () async -> Void)? = nil,
    quietInterval: Duration = .seconds(10)
  ) {
    self.session = session
    self.loadAccount = loadAccount
    self.quietInterval = quietInterval
    reload()
  }

  // MARK: - What the pending screen reads

  /// The failed item `item` waits behind, directly or through another it waits for.
  public func heldBehind(_ item: OutboxItem) -> OutboxItem? {
    var seen: Set<UUID> = []
    var queue = dependencies(of: item)
    while let next = queue.popLast() {
      guard seen.insert(next.id).inserted else { continue }
      if next.isFailed { return next }
      queue += dependencies(of: next)
    }
    return nil
  }

  /// The dive creates waiting, logs of drafts among them: what the offline number counts.
  public var queuedDiveCreates: Int {
    items.filter { $0.operation.diveCreate != nil }.count
  }

  /// The number of the newest-dated dive the phone has seen, for the number offered offline.
  public var highestKnownDiveNumber: Int? {
    AccountStores.current(session)?.cache.highestDiveNumber
  }

  /// The queued updates of a dive, in order.
  public func pendingUpdates(ofDive ref: RecordRef) -> [DiveUpdate] {
    items.compactMap { item in
      if case .updateDive(let target, let update) = item.operation, target == ref {
        return update
      }
      return nil
    }
  }

  public func item(_ id: UUID) -> OutboxItem? {
    items.first { $0.id == id }
  }

  /// A dive the phone has shown, as the cache holds it with its queued edits laid over: what
  /// the edit form opens on before, or without, a fetch.
  public func cachedDive(_ uuid: UUID) -> DiveReadWithMixtures? {
    guard let stores = AccountStores.current(session),
      let dive = stores.cache.dive(uuid)?.value.dive
    else { return nil }
    let updates = pendingUpdates(ofDive: .server(uuid))
    return dive.applying(updates, tables: LookupTables(cache: stores.cache, items: items)) ?? dive
  }

  // MARK: - Queueing

  /// Queues a write and returns the item, on disk before this returns; a create's
  /// ``OutboxItem/creates`` is the local ref to select. A draft's writes go through
  /// ``beginDraft(_:)`` and the methods beside it.
  @discardableResult
  public func queue(_ operation: OutboxOperation) throws -> OutboxItem {
    switch operation {
    case .createDiveDraft, .updateDiveDraft, .deleteDiveDraft, .logDive:
      throw OutboxError.draftOperation
    default:
      return try append(operation, flush: true)
    }
  }

  func append(_ operation: OutboxOperation, flush: Bool) throws -> OutboxItem {
    guard let stores = AccountStores.current(session) else { throw OutboxError.noAccount }
    var operation = operation
    let resolutions = stores.outbox.resolutions()
    operation.rewriteRefs { ref in
      guard case .local(let local) = ref, let server = resolutions[local]?.server else {
        return ref
      }
      return .server(server)
    }
    let item = OutboxItem(
      operation: operation, sequence: stores.outbox.nextSequence(), marked: stores.marked)
    try stores.outbox.save(item)
    changed(stores)
    if flush { requestFlush(retryAll: false) }
    return item
  }

  /// The diver's *Edit*: the item again with the body corrected, under its key. A create the
  /// server may hold under its key cannot be edited (``OutboxItem/isEditable``).
  public func edit(_ id: UUID, _ operation: OutboxOperation) throws {
    guard let stores = AccountStores.current(session),
      var item = stores.outbox.items().first(where: { $0.id == id }), item.isEditable,
      Self.sameShape(item.operation, operation)
    else { throw OutboxError.notEditable }
    item.operation = operation
    item.changedAt = Date()
    item.state = .pending(lastAnswer: nil)
    if operation.isCreate {
      item.sentBody = nil
      item.attempted = false
    }
    try stores.outbox.save(item)
    OutboxHub.hub(for: stores.directory).answers[id] = nil
    changed(stores)
    requestFlush(retryAll: false)
  }

  /// What discarding `id` changes: the items that name the record it creates and go on
  /// without it, and those that write to it and go with it — a log of a discarded draft
  /// becoming a plain dive.
  public func discardEffects(_ id: UUID) -> (released: [OutboxItem], withdrawn: [OutboxItem]) {
    guard let ref = item(id)?.creates else { return ([], []) }
    let others = items.filter { $0.id != id }
    let withdrawn = others.filter { $0.operation.target == ref }
    let released = others.filter {
      $0.operation.target != ref && $0.operation.references.contains(ref)
    }
    return (released, withdrawn)
  }

  /// The diver's *Discard*. What named the record it would have created drops the reference
  /// and goes on, and what wrote to that record goes with it.
  public func discard(_ id: UUID) {
    guard let stores = AccountStores.current(session),
      let item = stores.outbox.items().first(where: { $0.id == id })
    else { return }
    stores.outbox.remove(id)
    if let ref = item.creates {
      release(ref, in: stores.outbox)
    }
    changed(stores)
  }

  /// Every remaining item stops naming `ref`; a write to it goes, except a log of the draft,
  /// which carries the whole dive and becomes a plain create of it.
  func release(_ ref: RecordRef, in outbox: OutboxStore) {
    for var other in outbox.items() {
      if other.operation.target == ref {
        if case .logDive(_, let dive) = other.operation {
          other.operation = .createDive(dive)
          try? outbox.save(other)
        } else {
          outbox.remove(other.id)
        }
        continue
      }
      let before = other.operation
      other.operation.rewriteRefs { $0 == ref ? nil : $0 }
      if other.operation != before { try? outbox.save(other) }
    }
  }

  /// *Discard* on an item this build cannot read.
  public func discardUnreadable(_ name: String) {
    guard let stores = AccountStores.current(session) else { return }
    stores.outbox.removeUnreadable(name)
    changed(stores)
  }

  public func dismiss(_ notice: OutboxNotice) {
    guard let stores = AccountStores.current(session) else { return }
    stores.outbox.removeNotice(notice.id)
    changed(stores)
  }

  // MARK: - Triggers

  /// *Sync now*: every item, passed-over ones included, after the account load where none has
  /// returned in this process.
  public func syncNow() {
    if session.accountLoaded {
      requestFlush(retryAll: true)
    } else {
      loadThenFlush(retryAll: true)
    }
  }

  /// A route appearing or the app becoming active: a flush, and the lookups, after the account
  /// load where none has returned.
  public func handle(_ moment: ConnectivityMoment) {
    guard case .signedIn = session.state else { return }
    if session.accountLoaded {
      requestFlush(retryAll: false)
      Task { await LookupsModel.refresh(session) }
    } else {
      loadThenFlush(retryAll: false)
    }
  }

  /// Handles every moment the session's connectivity reports, until cancelled.
  public func watch() async {
    for await moment in session.connectivity.moments() {
      handle(moment)
    }
  }

  /// The session changed — signed in or out, or the account loaded. A load settles what was
  /// written before it — kept, or moved to the loaded account's stores — then flushes and
  /// refreshes the drafts and the lookups; a session that ended before one leaves the writes
  /// with the account they were written for.
  public func sessionChanged() {
    sessionChanged(retryAll: false)
  }

  private func sessionChanged(retryAll: Bool) {
    guard let origin = session.state.origin else {
      reload()
      return
    }
    switch session.state {
    case .signingIn:
      for outbox in OutboxStore.all(store: session.store, origin: origin) {
        clearMarks(in: outbox)
      }
    case .signedIn where session.accountLoaded:
      if let user = session.user {
        settleMarks(origin: origin, loaded: user)
      }
    default:
      break
    }
    reload()
    guard session.accountLoaded else { return }
    requestFlush(retryAll: retryAll)
    Task { await LookupsModel.refresh(session) }
  }

  /// Waits for the account load, the quiet interval and the flush in flight, and any they
  /// started.
  public func settled() async {
    while true {
      if let task = loadTask {
        await task.value
        continue
      }
      if let task = quietTask {
        await task.value
        continue
      }
      guard let stores = AccountStores.current(session) else { return }
      let hub = OutboxHub.hub(for: stores.directory)
      if let task = hub.flush {
        await task.value
        continue
      }
      if let task = hub.draftsRefresh {
        await task.value
        continue
      }
      if let task = hub.lookupsRefresh {
        await task.value
        continue
      }
      return
    }
  }

  private func loadThenFlush(retryAll: Bool) {
    guard case .signedIn = session.state, loadTask == nil else { return }
    let load = loadAccount
    let session = session
    loadTask = Task {
      await OutboxHub.loadAccount(key: ObjectIdentifier(session)) {
        if let load {
          await load()
        } else {
          try? await session.loadAccount()
        }
      }
      loadTask = nil
      guard session.accountLoaded else { return }
      sessionChanged(retryAll: retryAll)
    }
  }

  // MARK: - Reading

  /// Reads the stores the session names again.
  public func reload() {
    guard let stores = AccountStores.current(session) else {
      (items, unreadable, notices, drafts, account, sending) = ([], [], [], [], nil, nil)
      isFlushing = false
      return
    }
    let hub = OutboxHub.hub(for: stores.directory)
    hub.observe(self)
    account = stores.account
    let outbox = stores.outbox
    items = outbox.items().map { item in
      var item = item
      if hub.sending == item.id { item.state = .inFlight }
      return item
    }
    unreadable = outbox.unreadableItems()
    notices = outbox.notices()
    drafts = DiveDraftEntry.list(cached: stores.cache.diveDrafts?.value ?? [], items: items)
    sending = hub.sending
    isFlushing = hub.flush != nil
  }

  func accountStoresChanged() { reload() }

  func changed(_ stores: AccountStores) {
    OutboxHub.hub(for: stores.directory).changed()
  }

  // MARK: - Dependencies

  /// The items `item` waits for: the creates of the records it names, and the earlier writes
  /// to its own record.
  func dependencies(of item: OutboxItem) -> [OutboxItem] {
    Self.dependencies(of: item, among: items)
  }

  static func dependencies(of item: OutboxItem, among items: [OutboxItem]) -> [OutboxItem] {
    let refs = Set(item.operation.references.filter(\.isLocal))
    return items.filter { other in
      guard other.id != item.id else { return false }
      if let created = other.creates, refs.contains(created) { return true }
      if let record = item.record, other.record == record,
        (other.sequence, other.queuedAt) < (item.sequence, item.queuedAt)
      {
        return true
      }
      return false
    }
  }

  static func sameShape(_ a: OutboxOperation, _ b: OutboxOperation) -> Bool {
    switch (a, b) {
    case (.createDive, .createDive), (.createDiveSite, .createDiveSite),
      (.createPerson, .createPerson), (.createTrip, .createTrip), (.createCourse, .createCourse),
      (.createContact, .createContact), (.createGearItem, .createGearItem),
      (.createGearSet, .createGearSet), (.createDiveDraft, .createDiveDraft):
      return true
    case (.logDive(let x, _), .logDive(let y, _)): return x == y
    case (.updateDive(let x, _), .updateDive(let y, _)): return x == y
    case (.updateGearSet(let x, _), .updateGearSet(let y, _)): return x == y
    case (.updateDiveDraft(let x, _), .updateDiveDraft(let y, _)): return x == y
    default: return false
    }
  }
}
