import Foundation

/// Which dives a walk takes, decided once its list is read and before its first transfer: the
/// dives the logbook holds are left out, and a walk the diver watches asks the rest of the way.
///
/// **A computer awaits its question on each account** whose progress holds neither a fingerprint
/// nor an answer (``DiveComputerRecord/awaitsQuestion``): a watched walk asks *Which dives do you
/// want to download?*, and a walk nobody watches is not started (``connected(_:record:handedOver:)``).
/// *Choose dives to download* shows the list whatever the computer's progress.
///
/// **What the diver did not choose is not taken again**, kept with the dives the server answered
/// for until the fingerprint next moves (``DownloadStore/choose(_:declined:of:)``), so a walk
/// that breaks off after a choice resumes in any later walk and asks nothing again.
extension DiveComputerEngine {
  /// The fingerprints of `listed` that the walk leaves out: those the logbook holds, and, where
  /// the walk asks, those the diver did not choose. Cancelled at the question or the list, every
  /// one, the link told to stop.
  func leftOut(
    _ walk: DiveComputerWalk, _ identity: DiveComputerIdentity,
    _ listed: [DiveComputerListing.Download], account: UUID, marked: Bool,
    store: DiveComputerStore, downloads: DownloadStore
  ) async -> Set<Data> {
    let held = await heldByLogbook(identity, listed, account: account, marked: marked)
    let logbook = held ?? []
    let left = listed.filter { !logbook.contains($0.fingerprint) }
    walk.logbookHoldsAll = !logbook.isEmpty && left.isEmpty
    let record = store.record(family: identity.family, serial: identity.serial)
    guard walk.watched, !walk.cancelled, walk.choosing || record?.awaitsQuestion != false else {
      return logbook
    }
    guard !left.isEmpty else {
      if !walk.choosing, var record {
        record.answeredQuestion = true
        try? store.save(record)
      }
      return logbook
    }
    walk.choice = DownloadChoice(
      stage: walk.choosing ? .list : .question, dives: left, checked: held != nil,
      computer: identity.title, watchZone: inFlight?.watchZone,
      pace: DownloadPace.before(identity.family, kept: record?.downloadPace))
    walk.phase = .choosingDives
    let chosen = await withCheckedContinuation { choiceAnswer = $0 }
    walk.choice = nil
    if walk.phase == .choosingDives { walk.phase = .connecting }
    guard let chosen else {
      link.cancelDownload()
      return Set(listed.map(\.fingerprint))
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
    return Set(declined.map(\.fingerprint))
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
