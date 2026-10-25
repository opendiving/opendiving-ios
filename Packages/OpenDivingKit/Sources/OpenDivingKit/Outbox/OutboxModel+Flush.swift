import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

extension OutboxModel {
  /// Starts a flush of the loaded account's outbox, or asks the one running for another pass.
  /// With no route only *Sync now* starts one; the app's own triggers leave the queue to the
  /// moment a route appears.
  func requestFlush(retryAll: Bool) {
    guard retryAll || session.connectivity.isRouteAvailable,
      let stores = AccountStores.current(session), stores.loaded,
      let client = try? session.requireClient()
    else { return }
    let hub = OutboxHub.hub(for: stores.directory)
    if hub.flush != nil {
      hub.again = (hub.again ?? false) || retryAll
      return
    }
    let session = session
    hub.flush = Task { @MainActor in
      await Self.runFlushes(stores, client, hub, session, retryAll: retryAll)
    }
    hub.changed()
  }

  private static func runFlushes(
    _ stores: AccountStores, _ client: APIClient, _ hub: OutboxHub, _ session: Session,
    retryAll: Bool
  ) async {
    var retryAll = retryAll
    // An ask that arrives while the assertion ends is a pass of its own: `again` is read last,
    // with no suspension between that and clearing the slot.
    repeat {
      let token = await session.background.begin(name: "Sending what the server has not saved")
      while true {
        hub.again = nil
        let flush = Flush(stores: stores, client: client, hub: hub, session: session)
        let outcome = await flush.run(retryAll: retryAll)
        if outcome.changedLists { hub.listsChanged() }
        // A flush stopped for want of a route is followed by one at the next moment, which
        // reads the drafts then.
        if outcome.reachedServer {
          await OutboxModel.refreshDrafts(session)
        }
        if outcome.landedRecord {
          await LookupsModel.refresh(session)
        }
        guard let again = hub.again else { break }
        retryAll = again
      }
      stores.outbox.pruneResolutions()
      await session.background.end(token)
      retryAll = hub.again ?? false
    } while hub.again != nil
    hub.flush = nil
    hub.sending = nil
    hub.changed()
  }
}

/// One flush of one account's outbox.
@MainActor
private struct Flush {
  let stores: AccountStores
  let client: APIClient
  let hub: OutboxHub
  let session: Session

  struct Outcome {
    var reachedServer = true
    var landedRecord = false
    /// A write to a record a tab lists landed.
    var changedLists = false
  }

  /// What sending one item came to.
  enum Step {
    /// No route, a refused session, the account changed: nothing more is sent.
    case stop
    /// The queue changed under the items still to go — something landed or became something
    /// else — so they are read again.
    case changed
    /// Only this item changed.
    case next
  }

  var outbox: OutboxStore { stores.outbox }

  func run(retryAll: Bool) async -> Outcome {
    var outcome = Outcome()
    hub.tried = []
    passes: while true {
      let items = outbox.items()
      for item in items {
        guard stores.sameAccount(AccountStores.current(session)),
          retryAll || session.connectivity.isRouteAvailable
        else {
          outcome.reachedServer = false
          break passes
        }
        guard item.isPending, !item.writtenBeforeAccountKnown, !hub.tried.contains(item.id),
          retryAll || hub.answers[item.id, default: 0] < 2,
          retryAll || !isBeingEdited(item),
          OutboxModel.dependencies(of: item, among: items).isEmpty
        else { continue }
        hub.tried.insert(item.id)
        switch await send(item, &outcome) {
        case .stop:
          outcome.reachedServer = false
          break passes
        case .changed: continue passes
        case .next: continue
        }
      }
      break
    }
    return outcome
  }

  private func isBeingEdited(_ item: OutboxItem) -> Bool {
    switch item.operation {
    case .createDiveDraft, .updateDiveDraft:
      item.record.map(hub.editing.contains) ?? false
    default: false
    }
  }

  // MARK: - Sending

  private func send(_ queued: OutboxItem, _ outcome: inout Outcome) async -> Step {
    // The pass's copy may be stale: the diver can edit or discard anything but the item being
    // sent while an earlier one waited on the network.
    guard outbox.items().first(where: { $0.id == queued.id }) == queued else {
      hub.tried.remove(queued.id)
      return .changed
    }
    var item = queued
    let resolutions = outbox.resolutions()
    var lost: String?
    item.operation.rewriteRefs { ref in
      guard case .local(let local) = ref else { return ref }
      guard let resolution = resolutions[local] else { return nil }
      if let server = resolution.server { return .server(server) }
      lost = resolution.sentence ?? OutboxText.landedUnreadable
      return ref
    }
    if let target = item.operation.target, target.isLocal {
      // A write to a record that will never exist: a log carries its dive and becomes it.
      if case .logDive(_, let dive) = item.operation {
        item.operation = .createDive(dive)
        save(item)
        hub.tried.remove(item.id)
        return .changed
      }
      fail(&item, .unresolvable, message: lost ?? OutboxText.namesNothing)
      return .next
    }
    if let lost {
      fail(&item, .unresolvable, message: lost)
      return .next
    }

    let request: (method: String, path: String, body: Data?)
    do {
      request = try item.operation.request()
    } catch {
      fail(&item, .unresolvable, message: OutboxText.namesNothing)
      return .next
    }
    var body = request.body
    let keyed = item.operation.isCreate
    if keyed {
      if let sent = item.sentBody {
        body = sent
      } else {
        item.sentBody = body
      }
      item.attempted = true
    }
    item.state = .inFlight
    let routed = session.connectivity.isRouteAvailable
    let appearances = session.connectivity.routeAppearances
    // Not on disk, not sent: the attempt and its bytes must survive the reply being lost.
    guard (try? outbox.save(item)) != nil else { return .stop }
    hub.sending = item.id
    hub.changed()
    defer {
      hub.sending = nil
      hub.changed()
    }

    let data: Data
    let response: HTTPURLResponse
    do {
      (data, response) = try await client.sendQueued(
        method: request.method, path: request.path, body: body,
        idempotencyKey: keyed ? item.idempotencyKey : nil)
    } catch {
      let unreachable = if case .unreachable = APIError(error) { true } else { false }
      item.state = .pending(lastAnswer: unreachable ? .unreachable : queued.lastAnswer)
      // Sent with no route and none appearing since, the request waited on the phone for one
      // and timed out there, so the create can still be edited or withdrawn.
      if unreachable, !routed, session.connectivity.routeAppearances == appearances {
        item.attempted = queued.attempted
        item.sentBody = queued.sentBody
      }
      save(item)
      return .stop
    }
    return await sort(item, data, response.statusCode, &outcome)
  }

  private func sort(
    _ item: OutboxItem, _ data: Data, _ status: Int, _ outcome: inout Outcome
  ) async -> Step {
    var item = item
    let keyed = item.operation.isCreate
    switch status {
    case 200..<300:
      outcome.changedLists = outcome.changedLists || item.operation.changesLists
      let landed: LandedRecord?
      do {
        landed = try item.operation.landed(data)
      } catch {
        return lostCreate(item, sentence: OutboxText.landedUnreadable)
      }
      outcome.landedRecord = outcome.landedRecord || landed != nil || isGearSetUpdate(item)
      return await land(item, landed)
    case 409 where keyed:
      item.state = .pending(lastAnswer: .status(status))
      save(item)
      return .next
    case 410 where keyed:
      return lostCreate(
        item, sentence: APIClient.detail(of: data) ?? OutboxText.createdThenDeleted)
    case 404:
      switch item.operation {
      case .updateDiveDraft(let ref, _), .deleteDiveDraft(let ref):
        outbox.remove(item.id)
        notice(.diveDraft, OutboxText.draftGone)
        if let uuid = ref.serverUUID { stores.cache.removeDiveDraft(uuid) }
        return .changed
      case .logDive(let draft, let dive):
        // The draft went on another device: the dive the diver logged here is still a dive.
        item.operation = .createDive(dive)
        item.state = .pending(lastAnswer: .status(status))
        save(item)
        hub.tried.remove(item.id)
        if let uuid = draft.serverUUID { stores.cache.removeDiveDraft(uuid) }
        return .changed
      default:
        break
      }
    case 429, 500...:
      item.state = .pending(lastAnswer: .status(status))
      save(item)
      hub.answers[item.id, default: 0] += 1
      return .next
    case 400..<500:
      break
    default:
      item.state = .pending(lastAnswer: .status(status))
      save(item)
      return .next
    }
    fail(
      &item, .refused, status: status,
      message: APIClient.detail(of: data) ?? "The server answered \(status).")
    return .next
  }

  private func isGearSetUpdate(_ item: OutboxItem) -> Bool {
    if case .updateGearSet = item.operation { true } else { false }
  }

  // MARK: - Landing

  /// A success, read. A create is done once its resolution is written.
  private func land(_ item: OutboxItem, _ landed: LandedRecord?) async -> Step {
    let cache = stores.cache
    if let local = item.creates, let landed {
      let server = landed.uuid
      guard
        (try? outbox.record(
          OutboxStore.Resolution(local: local.uuid, server: server, sentence: nil))) != nil
      else { return .stop }
      rewrite(local, to: .server(server))
      upsertRow(item, landed)
    }
    if case .updateDive(let ref, let update) = item.operation, let uuid = ref.serverUUID {
      keepLanded(update, ofDive: uuid)
    }
    outbox.remove(item.id)
    hub.answers[item.id] = nil

    switch (item.operation, landed) {
    case (.createDive, .dive(let dive)), (.logDive, .dive(let dive)):
      cache.raiseHighestDiveNumber(to: dive.diveNumber)
      if case .logDive(let draft, _) = item.operation, let uuid = draft.serverUUID {
        cache.removeDiveDraft(uuid)
      }
      await readBack(dive: dive.uuid)
    case (.updateDive(let ref, _), _):
      if let uuid = ref.serverUUID { await readBack(dive: uuid) }
    case (.createDiveDraft, .draft(let draft)):
      cache.replaceDiveDraft(draft)
      await readBack(draft: draft.uuid)
    case (.updateDiveDraft(let ref, _), _):
      if let uuid = ref.serverUUID { await readBack(draft: uuid) }
    case (.deleteDiveDraft(let ref), _):
      if let uuid = ref.serverUUID { cache.removeDiveDraft(uuid) }
    default:
      break
    }
    return .changed
  }

  /// A create that is done but can never be named: landed in a form this build cannot read,
  /// or deleted before the retry. What named it fails with the sentence; a log of the draft
  /// it made carries its dive and becomes a plain create of it.
  private func lostCreate(_ item: OutboxItem, sentence: String) -> Step {
    if let local = item.creates {
      guard
        (try? outbox.record(
          OutboxStore.Resolution(local: local.uuid, server: nil, sentence: sentence))) != nil
      else { return .stop }
      for var other in outbox.items() where other.id != item.id {
        if other.operation.target == local, case .logDive(_, let dive) = other.operation {
          other.operation = .createDive(dive)
          save(other)
        } else if other.operation.references.contains(local), !other.isFailed {
          fail(&other, .unresolvable, message: sentence)
        }
      }
    }
    if case .logDive(let draft, _) = item.operation, let uuid = draft.serverUUID {
      stores.cache.removeDiveDraft(uuid)
    }
    outbox.remove(item.id)
    hub.answers[item.id] = nil
    notice(item.operation.kind, sentence)
    return .changed
  }

  /// Every item still queued names the record by the server's uuid.
  private func rewrite(_ local: RecordRef, to server: RecordRef) {
    for var other in outbox.items() {
      let before = other.operation
      other.operation.rewriteRefs { $0 == local ? server : $0 }
      if other.operation != before { save(other) }
    }
  }

  /// The landed record's row in its picker, under the server's ref until the next refresh
  /// brings the server's own.
  private func upsertRow(_ item: OutboxItem, _ landed: LandedRecord) {
    let cache = stores.cache
    let ref = RecordRef.server(landed.uuid)
    switch (item.operation, landed) {
    case (.createDiveSite(let body), _):
      cache.upsertLookupRow(body.lookupRow(ref), table: .diveSites)
    case (.createTrip(let body), _): cache.upsertLookupRow(body.lookupRow(ref), table: .trips)
    case (.createPerson(let body), _): cache.upsertLookupRow(body.lookupRow(ref), table: .people)
    case (.createCourse(let body), _):
      cache.upsertLookupRow(body.lookupRow(ref), table: .courses)
    case (.createContact(let body), _):
      cache.upsertLookupRow(body.lookupRow(ref), table: .contacts)
    case (.createGearItem(let body), _):
      cache.upsertLookupRow(body.lookupRow(ref), table: .gearItems)
    case (.createGearSet, .gearSet(let set)):
      cache.upsertLookupRow(GearSetRow(set), table: .gearSets)
    default: break
    }
  }

  // MARK: - Reading back

  /// The cached dive with a landed edit in it, so nothing shows the dive without the edit
  /// while the read-back is on its way, or when it fails.
  private func keepLanded(_ update: DiveUpdate, ofDive uuid: UUID) {
    let cache = stores.cache
    guard var entry = cache.dive(uuid)?.value,
      let edited = entry.dive.applying(
        [update], tables: LookupTables(cache: cache, items: outbox.items()))
    else { return }
    entry.replace(edited)
    cache.writeDive(entry)
  }

  /// The dive as the server now holds it, in place of the cached copy.
  private func readBack(dive uuid: UUID) async {
    guard let dive = try? await client.dive(uuid) else { return }
    let cache = stores.cache
    var entry = cache.dive(uuid)?.value ?? AccountCache.Dive(dive: dive)
    entry.replace(dive)
    cache.writeDive(entry)
  }

  /// The draft as the server now holds it, unless a write to it is still queued: a newer
  /// state stays the phone's copy until it lands, and a log or a discard keeps it out.
  private func readBack(draft uuid: UUID) async {
    guard let draft = try? await client.diveDraft(uuid) else { return }
    let ref = RecordRef.server(uuid)
    guard !outbox.items().contains(where: { $0.record == ref }) else { return }
    stores.cache.replaceDiveDraft(draft)
  }

  // MARK: - Writing

  private func save(_ item: OutboxItem) {
    try? outbox.save(item)
  }

  private func fail(
    _ item: inout OutboxItem, _ kind: OutboxFailure.Kind, status: Int? = nil, message: String
  ) {
    item.state = .failed(OutboxFailure(kind: kind, status: status, message: message))
    save(item)
  }

  private func notice(_ kind: OutboxRecordKind, _ sentence: String) {
    try? outbox.add(OutboxNotice(kind: kind, sentence: sentence))
  }
}
