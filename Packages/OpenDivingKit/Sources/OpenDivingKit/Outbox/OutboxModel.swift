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
/// and flushes on its success. While the session's connectivity reports no route only *Sync
/// now* sends: the rest wait for the moment a route appears.
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
    /// A card image goes through ``queueCardImage(_:as:of:)``, which keeps its bytes.
    case cardImageOperation
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
    case .putCertificationFile:
      throw OutboxError.cardImageOperation
    case .deleteCertificationFile(let ref, let side):
      withdrawCardWrites(of: ref, side: side)
      return try append(operation, flush: true)
    default:
      if let deleted = operation.deletedRecordRef { withdrawWrites(to: deleted) }
      return try append(operation, flush: true)
    }
  }

  /// Queues `data` as one side's image of `certification`, the bytes on disk before this
  /// returns, in place of any image or removal of that side still waiting. It is sent once the
  /// certification's own writes are, and its bytes go when it lands or is discarded.
  @discardableResult
  public func queueCardImage(
    _ data: Data, as upload: CertificationCardUpload, of certification: RecordRef
  ) throws -> OutboxItem {
    withdrawCardWrites(of: certification, side: upload.side)
    return try append(.putCertificationFile(certification, upload), flush: true) { item, outbox in
      try outbox.writeCardFile(data, for: item.id)
    }
  }

  /// A record being deleted needs no write still waiting for it, least of all a refused one the
  /// delete would wait behind, nor any that cannot go on without it. The one being sent stays,
  /// and the delete follows it.
  private func withdrawWrites(to ref: RecordRef) {
    guard let stores = AccountStores.current(session) else { return }
    let sending = OutboxHub.hub(for: stores.directory).sending
    for item in Self.withdrawn(by: ref, among: stores.outbox.items()) where item.id != sending {
      stores.outbox.remove(item.id)
    }
  }

  /// The latest write to a side wins: an image or a removal of it still waiting is replaced.
  private func withdrawCardWrites(of certification: RecordRef, side: CertificationSide) {
    guard let stores = AccountStores.current(session) else { return }
    let ref = stores.outbox.resolved(certification)
    let sending = OutboxHub.hub(for: stores.directory).sending
    for item in stores.outbox.items() where item.id != sending {
      switch item.operation {
      case .putCertificationFile(ref, let upload) where upload.side == side,
        .deleteCertificationFile(ref, side):
        stores.outbox.remove(item.id)
      default:
        break
      }
    }
  }

  /// `beforeSaving` writes what the item needs on disk before the item itself is.
  func append(
    _ operation: OutboxOperation, flush: Bool,
    beforeSaving: (OutboxItem, OutboxStore) throws -> Void = { _, _ in }
  ) throws -> OutboxItem {
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
    do {
      try beforeSaving(item, stores.outbox)
      try stores.outbox.save(item)
    } catch {
      stores.outbox.remove(item.id)
      throw error
    }
    changed(stores)
    if flush { requestFlush(retryAll: false) }
    return item
  }

  /// The diver's *Edit*: the item again with the body corrected, under its key. A create the
  /// server may hold under its key cannot be edited (``OutboxItem/isEditable``).
  public func edit(_ id: UUID, _ operation: OutboxOperation) throws {
    guard let stores = AccountStores.current(session),
      case let sending = OutboxHub.hub(for: stores.directory).sending, sending != id,
      case let queued = stores.outbox.items(),
      var item = queued.first(where: { $0.id == id }), item.isEditable,
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
    if case .createDiveDraft = operation, let ref = item.creates {
      Self.dropUpdates(ofDraft: ref, in: queued, stores.outbox, sending: sending)
    }
    OutboxHub.hub(for: stores.directory).answers[id] = nil
    changed(stores)
    requestFlush(retryAll: false)
  }

  /// What discarding `id` changes: the items that name a record it would have created and go
  /// on without it, and those that cannot go on without one and go with it — a log of a
  /// discarded draft becoming a plain dive.
  public func discardEffects(_ id: UUID) -> (released: [OutboxItem], withdrawn: [OutboxItem]) {
    guard let ref = item(id)?.creates else { return ([], []) }
    let others = items.filter { $0.id != id }
    let withdrawn = Self.withdrawn(by: ref, among: others)
    let gone = Self.records(withdrawnWith: ref, withdrawn)
    let released = others.filter { other in
      !withdrawn.contains { $0.id == other.id }
        && other.operation.references.contains(where: gone.contains)
    }
    return (released, withdrawn)
  }

  /// The diver's *Discard*. What cannot go on without the record it would have created goes
  /// with it, and so on down what cannot go on without those; what only named one of them drops
  /// the reference and goes on. The item being sent stays.
  public func discard(_ id: UUID) {
    guard let stores = AccountStores.current(session),
      OutboxHub.hub(for: stores.directory).sending != id,
      let item = stores.outbox.items().first(where: { $0.id == id })
    else { return }
    stores.outbox.remove(id)
    if let ref = item.creates {
      release(ref, in: stores.outbox)
    }
    changed(stores)
  }

  /// Every write that cannot go on without `ref` goes, with what cannot go on without the
  /// records those would have created, except a log of the draft, which carries the whole dive
  /// and becomes a plain create of it. Every remaining item stops naming any of them.
  func release(_ ref: RecordRef, in outbox: OutboxStore) {
    let queued = outbox.items()
    let withdrawn = Self.withdrawn(by: ref, among: queued)
    let gone = Self.records(withdrawnWith: ref, withdrawn)
    let withdrawnIDs = Set(withdrawn.map(\.id))
    for var other in queued {
      if withdrawnIDs.contains(other.id) {
        if case .logDive(_, let dive) = other.operation {
          other.operation = .createDive(dive)
          try? outbox.save(other)
        } else {
          outbox.remove(other.id)
        }
        continue
      }
      let before = other.operation
      other.operation.rewriteRefs { gone.contains($0) ? nil : $0 }
      if other.operation != before { try? outbox.save(other) }
    }
  }

  /// The items that cannot go on once `ref` will never exist: each whose required records
  /// include it, and in turn each that requires a record one of those would have created. A
  /// log of a draft is among them but creates nothing that goes, since its dive is kept.
  static func withdrawn(by ref: RecordRef, among items: [OutboxItem]) -> [OutboxItem] {
    var gone: Set<RecordRef> = [ref]
    var withdrawn: [OutboxItem] = []
    var remaining = items
    while let index = remaining.firstIndex(where: {
      $0.operation.requiredRecords.contains(where: gone.contains)
    }) {
      let item = remaining.remove(at: index)
      withdrawn.append(item)
      if case .logDive = item.operation { continue }
      if let created = item.creates { gone.insert(created) }
    }
    return withdrawn
  }

  /// `ref` and every record the withdrawn items would have created, a log's dive aside.
  static func records(withdrawnWith ref: RecordRef, _ withdrawn: [OutboxItem]) -> Set<RecordRef> {
    var gone: Set<RecordRef> = [ref]
    for item in withdrawn {
      if case .logDive = item.operation { continue }
      if let created = item.creates { gone.insert(created) }
    }
    return gone
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
    case (.updateDiveSite(let x, _), .updateDiveSite(let y, _)): return x == y
    case (.updateTrip(let x, _), .updateTrip(let y, _)): return x == y
    case (.updateGearSet(let x, _), .updateGearSet(let y, _)): return x == y
    case (.createServiceSchedule, .createServiceSchedule),
      (.createServiceRecord, .createServiceRecord), (.createCertification, .createCertification):
      return true
    case (.updatePerson(let x, _), .updatePerson(let y, _)),
      (.updateCourse(let x, _), .updateCourse(let y, _)),
      (.updateContact(let x, _), .updateContact(let y, _)),
      (.updateGearItem(let x, _), .updateGearItem(let y, _)),
      (.updateServiceSchedule(let x, _, _), .updateServiceSchedule(let y, _, _)),
      (.updateServiceRecord(let x, _, _), .updateServiceRecord(let y, _, _)),
      (.updateCertification(let x, _), .updateCertification(let y, _)):
      return x == y
    case (.updateDiveDraft(let x, _), .updateDiveDraft(let y, _)): return x == y
    default: return false
    }
  }
}
