import Foundation

// A dive draft is the server's record, held by the phone and written through the queue like
// any other — but every change the diver makes is one, so its writes coalesce: one update per
// draft, replaced in place by the newer state, folded into the draft's own create while that
// has never been sent, and sent when the form is left or the changes pause.
extension OutboxModel {
  /// The diver's first change to a new form: the draft is a local record from now on, its
  /// create queued. Returns its ref.
  public func beginDraft(_ write: DiveDraftWrite) throws -> RecordRef {
    let item = try append(.createDiveDraft(write), flush: false)
    // A new item always carries the ref of what it creates.
    let ref = item.creates!
    scheduleQuietFlush(ref)
    return ref
  }

  /// Removes the queued updates of a draft whose create now carries its newest state: sent
  /// after the create lands, an older one would overwrite it.
  static func dropUpdates(
    ofDraft ref: RecordRef, in queued: [OutboxItem], _ outbox: OutboxStore, sending: UUID?
  ) {
    for item in queued where item.id != sending {
      if case .updateDiveDraft(let target, _) = item.operation, target == ref {
        outbox.remove(item.id)
      }
    }
  }

  /// A change to a draft: written now, sent when the form is left or the changes pause.
  public func saveDraft(_ ref: RecordRef, _ write: DiveDraftWrite) throws {
    guard let stores = AccountStores.current(session) else { throw OutboxError.noAccount }
    let outbox = stores.outbox
    let ref = outbox.resolved(ref)
    let queued = outbox.items()
    let sending = OutboxHub.hub(for: stores.directory).sending
    if var create = queued.first(where: { $0.creates == ref && $0.holdsNothing }),
      case .createDiveDraft = create.operation, create.id != sending
    {
      create.operation = .createDiveDraft(write)
      create.changedAt = Date()
      // A failed create goes again with the corrected state; one refused holds nothing under
      // its key, so its body is the diver's again.
      create.state = .pending(lastAnswer: create.lastAnswer)
      create.attempted = false
      create.sentBody = nil
      try outbox.save(create)
      Self.dropUpdates(ofDraft: ref, in: queued, outbox, sending: sending)
    } else if var update = queued.first(where: { item in
      guard case .updateDiveDraft(let target, _) = item.operation else { return false }
      return target == ref && item.id != sending
    }) {
      update.operation = .updateDiveDraft(ref, write)
      update.changedAt = Date()
      update.state = .pending(lastAnswer: update.lastAnswer)
      try outbox.save(update)
    } else {
      _ = try append(.updateDiveDraft(ref, write), flush: false)
    }
    changed(stores)
    scheduleQuietFlush(ref)
  }

  /// The form was left: what it queued goes now.
  public func leaveDraft() {
    quietTask?.cancel()
    quietTask = nil
    stopEditing()
    requestFlush(retryAll: false)
  }

  /// *Log dive* on a draft. A draft that has landed is logged by the log route, which removes
  /// it in the same request; one whose create was never sent is withdrawn with its updates and
  /// the dive created plainly; one whose create was sent waits for it, then logs. The draft
  /// leaves the list at once either way, so it cannot be logged twice. Returns the dive's ref.
  @discardableResult
  public func logDraft(_ ref: RecordRef, _ dive: DiveCreate) throws -> RecordRef {
    guard let stores = AccountStores.current(session) else { throw OutboxError.noAccount }
    let outbox = stores.outbox
    let ref = outbox.resolved(ref)
    OutboxHub.hub(for: stores.directory).editing.remove(ref)
    let queued = outbox.items()
    let operation: OutboxOperation
    if let create = queued.first(where: { $0.creates == ref }), create.holdsNothing {
      for item in queued where item.record == ref { outbox.remove(item.id) }
      operation = .createDive(dive)
    } else {
      withdrawUpdates(of: ref, in: queued, outbox, stores)
      operation = .logDive(fromDraft: ref, dive)
    }
    let item = try append(operation, flush: true)
    return item.creates!
  }

  /// *Discard draft*: a create never sent is withdrawn with its updates and nothing is sent;
  /// otherwise the delete is queued, behind the create where that has been attempted.
  public func discardDraft(_ ref: RecordRef) throws {
    guard let stores = AccountStores.current(session) else { throw OutboxError.noAccount }
    let outbox = stores.outbox
    let ref = outbox.resolved(ref)
    OutboxHub.hub(for: stores.directory).editing.remove(ref)
    let queued = outbox.items()
    if let create = queued.first(where: { $0.creates == ref }), create.holdsNothing {
      for item in queued where item.record == ref { outbox.remove(item.id) }
      changed(stores)
      return
    }
    withdrawUpdates(of: ref, in: queued, outbox, stores)
    _ = try append(.deleteDiveDraft(ref), flush: true)
  }

  /// The drafts list as the server holds it, every page, once the account has loaded.
  public func refreshDrafts() async {
    await Self.refreshDrafts(session)
    reload()
  }

  static func refreshDrafts(_ session: Session) async {
    guard let stores = AccountStores.current(session), stores.loaded,
      let client = try? session.requireClient()
    else { return }
    let hub = OutboxHub.hub(for: stores.directory)
    if let running = hub.draftsRefresh {
      await running.value
      return
    }
    let task = Task { @MainActor in
      let drafts = try? await APIClient.allPages(itemsPerPage: 100) {
        try await client.diveDrafts(page: $0, itemsPerPage: $1)
      }
      if let drafts {
        cacheForAnswer(fetchedUnder: stores, session: session)?.writeDiveDrafts(drafts)
      }
      hub.draftsRefresh = nil
      hub.changed()
    }
    hub.draftsRefresh = task
    await task.value
  }

  /// A log or a discard supersedes the draft's queued state; one being sent goes on.
  private func withdrawUpdates(
    of ref: RecordRef, in queued: [OutboxItem], _ outbox: OutboxStore, _ stores: AccountStores
  ) {
    let sending = OutboxHub.hub(for: stores.directory).sending
    for item in queued where item.id != sending {
      if case .updateDiveDraft(let target, _) = item.operation, target == ref {
        outbox.remove(item.id)
      }
    }
  }

  private func scheduleQuietFlush(_ ref: RecordRef) {
    if let stores = AccountStores.current(session) {
      OutboxHub.hub(for: stores.directory).editing.insert(ref)
    }
    quietTask?.cancel()
    let interval = quietInterval
    quietTask = Task { [weak self] in
      try? await Task.sleep(for: interval)
      guard !Task.isCancelled, let self else { return }
      quietTask = nil
      stopEditing()
      requestFlush(retryAll: false)
    }
  }

  private func stopEditing() {
    guard let stores = AccountStores.current(session) else { return }
    OutboxHub.hub(for: stores.directory).editing.removeAll()
  }
}
