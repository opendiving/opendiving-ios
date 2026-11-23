import Foundation

/// Which dives a walk takes, decided once its list is read and before its first transfer: the
/// dives the logbook holds are left out, a walk the diver watches asks the rest of the way, and
/// then the listed dives the logbook holds without the computer's original download are taken
/// after the rest, whatever was chosen.
///
/// **A computer awaits its question on each account** whose progress holds neither a fingerprint
/// nor an answer (``DiveComputerRecord/awaitsQuestion``): a watched walk asks *Which dives do you
/// want to download?*, and a walk nobody watches is not started (``connected(_:record:handedOver:)``).
/// *Choose dives to download* shows the list whatever the computer's progress.
///
/// **What the diver did not choose is not taken again** until the fingerprint next moves or the
/// computer is forgotten (``DownloadStore/choose(_:declined:of:)``), so a walk that breaks off
/// after a choice resumes in any later walk and asks nothing again.
///
/// **A dive taken for the computer's original is taken for it once** on an account: once the
/// server has answered for its import, no walk takes it for that reason again, whatever the server
/// says of it next (``DownloadStore/allSentForOriginal()``). Nor does a walk take one the phone
/// still keeps. What the phone need not take otherwise, and what the diver did not choose, do not
/// leave it out: a dive in the logbook adds nothing to it but its file.
extension DiveComputerEngine {
  /// What the walk leaves out of `listed`, the entries it would take — those the logbook holds,
  /// and, where the walk asks, those the diver did not choose — and which listed dives it takes
  /// after the rest: of `listed` and `others`, those the logbook holds without the computer's
  /// original that the phone neither keeps, of `kept`, nor has sent for it before. Cancelled at the
  /// question or the list, every one left out and none taken after, the link told to stop.
  func decided(
    _ walk: DiveComputerWalk, _ identity: DiveComputerIdentity,
    _ listed: [DiveComputerListing.Download], others: [DiveComputerListing.Download],
    account: UUID, marked: Bool, kept: Set<UUID>, store: DiveComputerStore,
    downloads: DownloadStore
  ) async -> DiveComputerListing.Decision {
    let known = await heldByLogbook(identity, listed + others, account: account, marked: marked)
    let logbook = Set(listed.map(\.fingerprint).filter { known?[$0] != nil })
    let left = listed.filter { !logbook.contains($0.fingerprint) }
    walk.logbookHoldsAll = !logbook.isEmpty && left.isEmpty
    let catchUp = catchUpDives(identity, listed + others, known: known, kept: kept, downloads)
    let record = store.record(family: identity.family, serial: identity.serial)
    guard walk.watched, !walk.cancelled, walk.choosing || record?.awaitsQuestion != false else {
      return taking(logbook, after: walk.cancelled ? [:] : catchUp, walk, identity)
    }
    guard !left.isEmpty else {
      if !walk.choosing, var record {
        record.answeredQuestion = true
        try? store.save(record)
      }
      return taking(logbook, after: catchUp, walk, identity)
    }
    walk.choice = DownloadChoice(
      stage: walk.choosing ? .list : .question, dives: left, checked: known != nil,
      computer: identity.title, watchZone: inFlight?.watchZone,
      pace: DownloadPace.before(identity.family, kept: record?.downloadPace))
    walk.phase = .choosingDives
    let chosen = await withCheckedContinuation { choiceAnswer = $0 }
    walk.choice = nil
    if walk.phase == .choosingDives { walk.phase = .connecting }
    guard let chosen else {
      link.cancelDownload()
      return taking(Set(listed.map(\.fingerprint)), after: [:], walk, identity)
    }
    walk.choseNone = chosen.isEmpty
    let declined = listed.filter { !chosen.contains($0.fingerprint) }
    func uuids(_ fingerprints: some Sequence<Data>) -> [UUID] {
      fingerprints.map { DiveComputerArchive.diveUUID(identity, fingerprint: $0) }
    }
    // Before the first transfer, so a walk that breaks off at any later moment resumes the
    // choice rather than asking again.
    try? downloads.choose(
      uuids(chosen), declined: uuids(declined.map(\.fingerprint)),
      of: DiveComputerRecord(identity: identity).id)
    if var saved = store.record(family: identity.family, serial: identity.serial) {
      saved.answeredQuestion = true
      if walk.choosing { saved.fingerprintSetAside = true }
      try? store.save(saved)
    }
    return taking(Set(declined.map(\.fingerprint)), after: catchUp, walk, identity)
  }

  /// Of `listed`, the dives `known` holds without the computer's original that the phone neither
  /// keeps nor has sent for it: by fingerprint, each with the logbook's dive that holds it.
  private func catchUpDives(
    _ identity: DiveComputerIdentity, _ listed: [DiveComputerListing.Download],
    known: [Data: KnownDive]?, kept: Set<UUID>, _ downloads: DownloadStore
  ) -> [Data: UUID] {
    guard let known else { return [:] }
    let sent = downloads.allSentForOriginal()
    var dives: [Data: UUID] = [:]
    for dive in listed {
      guard let row = known[dive.fingerprint], row.hasOriginal == false else { continue }
      let uuid = DiveComputerArchive.diveUUID(identity, fingerprint: dive.fingerprint)
      guard !kept.contains(uuid), !sent.contains(uuid) else { continue }
      dives[dive.fingerprint] = row.diveUuid
    }
    return dives
  }

  /// The decision, with what the walk takes after the rest kept with the walk: the fingerprints for
  /// its events, and the dives that hold them for its archives.
  private func taking(
    _ leftOut: Set<Data>, after catchUp: [Data: UUID], _ walk: DiveComputerWalk,
    _ identity: DiveComputerIdentity
  ) -> DiveComputerListing.Decision {
    walk.catchUp = Set(catchUp.keys)
    let updating = Dictionary(
      catchUp.map { (DiveComputerArchive.diveUUID(identity, fingerprint: $0.key), $0.value) },
      uniquingKeysWith: { first, _ in first })
    inFlight?.updating = updating
    inFlight?.keeper.updating(updating)
    return DiveComputerListing.Decision(leftOut: leftOut, catchUp: walk.catchUp)
  }

  /// A watched walk whose list leaves nothing to take has nothing to ask, which counts as
  /// answered: the link asks nothing of an empty list, and a computer left awaiting would never
  /// download by itself.
  func listedNothing(
    _ walk: DiveComputerWalk, _ listing: DiveComputerListing, store: DiveComputerStore
  ) {
    guard walk.watched, !walk.choosing, !walk.cancelled, listing.newDives == 0,
      listing.downloads.isEmpty, let identity = walk.identity,
      var record = store.record(family: identity.family, serial: identity.serial),
      record.awaitsQuestion
    else { return }
    record.answeredQuestion = true
    try? store.save(record)
  }

  /// *Choose dives*, at the question: the list in its place.
  public func showList(for walk: DiveComputerWalk) {
    guard walk === self.walk, walk.phase == .choosingDives, walk.choice?.stage == .question else {
      return
    }
    walk.choice?.stage = .list
  }

  /// The diver's answer at the question or the list: the fingerprints of the dives to take,
  /// every one for *Download all N dives* and none for *Only future dives*.
  public func choose(_ fingerprints: Set<Data>, for walk: DiveComputerWalk) {
    guard walk === self.walk, walk.phase == .choosingDives, let answer = choiceAnswer else {
      return
    }
    choiceAnswer = nil
    answer.resume(returning: fingerprints)
  }

  /// A walk nobody watches is not started for a computer that awaits its question on the account
  /// dives are kept for: it would take every dive unasked.
  func awaitsQuestion(_ record: DiveComputerRecord, account: UUID) -> Bool {
    guard let origin = session.state.origin else { return false }
    let store = DiveComputerStore(store: session.store, origin: origin, account: account)
    return store.record(family: record.family, serial: record.serial)?.awaitsQuestion ?? true
  }
}
