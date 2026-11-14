import Foundation
import Observation

/// The downloads from the phone's dive computers, for the app's whole process: a walk started by
/// the watch when a paired computer connects, or by the diver from the screen, each dive kept on
/// the phone as it arrives, each walk's dives one archive imported at once, and a notification
/// from the answer.
///
/// **One walk at a time.** A computer that connects while another is walked waits its turn. A
/// diver's tap is not a connection that waits: a walk nobody started ends with what it kept and
/// the tapped computer's starts, the latest action winning. A change of session ends a walk.
///
/// **A connection inside the revisit delay of a walk's end starts none**, in this process or an
/// earlier one: each walk's end is kept on disk (``WalkEnds``).
///
/// **Only a paired computer is read** by a walk nobody started: one that opens as a family and
/// serial with no pairing is closed unread.
///
/// **No route is needed to download**, and none to keep: a download on a boat is the point. What
/// is needed is an account to keep the dives for — the loaded one, or while signed in before it
/// loads the last one, marked, or signed out the last one — the inbox's rule for a shared file.
///
/// **The fingerprint advances only on a completed walk that met no empty read**, to the newest
/// entry walked, once the walk's dives are kept on the phone for the account it began for.
/// Before that the dives a walk kept, and those the server has answered for, are what a walk of
/// new dives does not take again (``DownloadStore``).
///
/// **No guessed time zone.** A dive whose start is an instant with no logged zone takes the
/// watch's zone while under a day old. Otherwise a walk the diver watches asks after the walk;
/// one nobody watches keeps those dives apart, and the screen asks when it is next opened.
///
/// **A walk nobody watches ends** after ``automaticWaitLimit`` without a dive arriving, with what
/// it kept.
@MainActor
@Observable
public final class DiveComputerEngine {
  /// The walk in flight, whoever started it.
  public private(set) var walk: DiveComputerWalk?
  /// The archives of the account dives are kept for now, oldest first.
  public private(set) var archives: [DownloadArchive] = []
  /// That account's dives waiting for the diver's time zone, a walk's at a time, oldest first.
  public private(set) var held: [HeldDives] = []

  /// Dives one walk kept apart until the diver says which zone they were in.
  public struct HeldDives: Hashable, Sendable, Identifiable {
    public let id: UUID
    public let dives: Int
    /// *Shearwater Perdix 3*.
    public let computer: String
    /// The zone the watch reported, which the question offers first.
    public let watchZone: TimeZone?
  }

  /// How long a walk nobody watches waits for its next dive before it ends.
  public static let automaticWaitLimit = Duration.seconds(10 * 60)

  @ObservationIgnored let session: Session
  @ObservationIgnored let watch: DiveComputerWatch?
  @ObservationIgnored let notifier: (any DiveComputerNotifier)?
  @ObservationIgnored let wake: (any ServerWake)?
  @ObservationIgnored private let makeLink: () -> any DiveComputerLink
  @ObservationIgnored private var madeLink: (any DiveComputerLink)?
  @ObservationIgnored private let writer: ComputerArchiveWriter
  @ObservationIgnored private let workFolder: URL
  @ObservationIgnored private let walkEnds: WalkEnds
  @ObservationIgnored let loadAccount: () async -> Void
  @ObservationIgnored let now: @Sendable () -> Date
  @ObservationIgnored let phoneZone: TimeZone
  @ObservationIgnored private let waitLimit: Duration
  /// Called once each dive a walk keeps is on disk: the watch walk's launch argument ends the
  /// app there.
  @ObservationIgnored public var diveKept: (() -> Void)?
  /// Called when a walk pairs a computer or changes what the phone remembers of it: the screen's
  /// rows follow.
  @ObservationIgnored var pairingsChanged: (() -> Void)?
  /// Called as each walk starts and once it has ended: the link stops a scan to download, so the
  /// screen stops its own, and starts it again after.
  @ObservationIgnored var walkStarting: ((DiveComputerWalk) -> Void)?
  @ObservationIgnored var walkEnded: ((DiveComputerWalk) -> Void)?

  private struct Queued {
    let walk: DiveComputerWalk
    /// The watch's peripheral it took, to hand back when the walk ends.
    let peripheral: UUID
  }

  @ObservationIgnored private var queue: [Queued] = []
  @ObservationIgnored private var running: Task<Void, Never>?
  @ObservationIgnored private var runningPeripheral: UUID?
  @ObservationIgnored private var zoneAnswer: CheckedContinuation<TimeZone?, Never>?
  /// Held walks whose answer is being written into an archive, and the writing.
  @ObservationIgnored private var answering: Set<UUID> = []
  @ObservationIgnored private var keepingAnswer: Task<Void, Never>?
  @ObservationIgnored var uploading: Task<Void, Never>?
  @ObservationIgnored var uploadAgain = false
  @ObservationIgnored private var moments: Task<Void, Never>?

  /// How long the watch's zone stands for a dive: a diver waits about a day to fly, so a dive
  /// younger than this was in the zone the watch shows now, and an older one may not have been.
  private static let watchZoneHolds: TimeInterval = 24 * 60 * 60

  /// `makeLink` makes the Bluetooth link the first time a walk or the screen needs it, never
  /// before — the device's asks for Bluetooth. `loadAccount` loads the account quietly, for an
  /// upload in a process that has not loaded it. `workFolder` is where archives are written
  /// before they are kept; `now` and `zone` are the clock and the phone's zone, which a test
  /// fixes.
  public init(
    session: Session, makeLink: @escaping () -> any DiveComputerLink,
    generator: ComputerArchiveWriter.Generator, watch: DiveComputerWatch? = nil,
    notifier: (any DiveComputerNotifier)? = nil, wake: (any ServerWake)? = nil,
    loadAccount: @escaping () async -> Void = {}, workFolder: URL? = nil,
    now: @escaping @Sendable () -> Date = { Date() }, zone: TimeZone = .current,
    waitLimit: Duration = automaticWaitLimit
  ) {
    self.session = session
    self.makeLink = makeLink
    self.watch = watch
    self.notifier = notifier
    self.wake = wake
    self.loadAccount = loadAccount
    writer = ComputerArchiveWriter(generator: generator)
    self.workFolder =
      workFolder
      ?? FileManager.default.temporaryDirectory.appendingPathComponent(
        "DiveComputerDownloads", isDirectory: true)
    walkEnds = WalkEnds(applicationSupport: session.store.applicationSupport)
    self.now = now
    phoneZone = zone
    self.waitLimit = waitLimit
    // Before the marks, which read an account's whole records as progress alone; here rather
    // than on a session change, so a cold start offline can download.
    DiveComputerStore.adoptAccountRecords(store: session.store)
    watch?.onConnected = { [weak self] peripheral, record in
      self?.connected(peripheral, record: record) ?? false
    }
  }

  /// The Bluetooth link, made on first use.
  public var link: any DiveComputerLink {
    if let madeLink { return madeLink }
    let made = makeLink()
    madeLink = made
    return made
  }

  // MARK: - The process

  /// The process began: the walks an ended process left become archives, and what waits is
  /// uploaded. Each route appearing and each return to the foreground uploads again.
  public func launched() {
    recoverEndedWalks()
    reload()
    upload()
    moments?.cancel()
    let stream = session.connectivity.moments()
    moments = Task { [weak self] in
      for await _ in stream { self?.upload() }
    }
  }

  /// The session changed — signed in or out, or another server: the walk in flight and those
  /// waiting their turn end, and the marks settle as the inbox's do.
  public func sessionChanged() {
    endWalks()
    settleMarks()
    reload()
    upload()
  }

  /// The account loaded: what was kept before it moves to it, and goes up.
  public func accountLoaded() {
    settleMarks()
    reload()
    upload()
  }

  /// Waits for the walks in flight and queued, a time-zone answer being kept, and the upload
  /// after them.
  public func settled() async {
    while let task = running ?? keepingAnswer ?? uploading { await task.value }
  }

  // MARK: - Starting walks

  /// A paired computer connected to the watch's request. Returns whether a walk takes the
  /// connection — now, or once the walk in flight ends — rather than the watch closing it.
  func connected(_ peripheral: UUID, record: DiveComputerRecord) -> Bool {
    if let ended = walkEnds.read()[record.id],
      now().timeIntervalSince(ended) < Double(DiveComputerWatch.revisitDelay)
    {
      return false
    }
    guard keeping() != nil else { return false }
    if runningPeripheral == peripheral || queue.contains(where: { $0.peripheral == peripheral }) {
      return true
    }
    let walk = DiveComputerWalk(
      computer: link.computer(for: record, at: peripheral), watched: false, all: false,
      record: record.id, zone: phoneZone)
    queue.append(Queued(walk: walk, peripheral: peripheral))
    next()
    return true
  }

  /// The diver's tap: a walk of `computer`, or with `all` of every dive on it. A walk nobody
  /// started ends with what it kept, and this one starts once it has. Nil where the diver's
  /// walk is already in flight or nothing can be kept.
  @discardableResult
  public func start(_ computer: FoundComputer, all: Bool) -> DiveComputerWalk? {
    guard keeping() != nil, walk?.watched != true, !queue.contains(where: \.walk.watched) else {
      return nil
    }
    let walk = DiveComputerWalk(computer: computer, watched: true, all: all, zone: phoneZone)
    watch?.downloadStarted(computer.id)
    // The tap walks the computer a connection queued: that walk is this one.
    queue.removeAll { $0.peripheral == computer.id }
    queue.insert(Queued(walk: walk, peripheral: computer.id), at: 0)
    if self.walk != nil { link.cancelDownload() }
    next()
    return walk
  }

  /// Stops the walk between dives; what it kept goes on. At the time-zone question, nothing is
  /// written.
  public func cancel(_ walk: DiveComputerWalk) {
    if let index = queue.firstIndex(where: { $0.walk === walk }) {
      let queued = queue.remove(at: index)
      walk.outcome = .init(kind: .cancelled, sentence: DiveComputerText.cancelled)
      walk.phase = .finished
      watch?.downloadEnded(queued.peripheral)
      return
    }
    guard walk === self.walk else { return }
    switch walk.phase {
    case .connecting, .downloading: link.cancelDownload()
    case .askingTimeZone:
      zoneAnswer?.resume(returning: nil)
      zoneAnswer = nil
    case .finished: break
    }
  }

  /// The diver's answer to *Which time zone were these dives in?*, for the walk's dives that
  /// logged no zone.
  public func answerTimeZone(_ zone: TimeZone, for walk: DiveComputerWalk) {
    guard walk === self.walk, walk.phase == .askingTimeZone else { return }
    zoneAnswer?.resume(returning: zone)
    zoneAnswer = nil
  }

  /// The diver's answer for the oldest dives held for a zone: they become an archive and go up.
  /// They leave ``held`` at once, so the question is not answered twice; the walk holding them,
  /// their only copy, goes only once the archive is kept, and comes back to ``held`` otherwise.
  public func answerHeld(_ zone: TimeZone) {
    guard let (account, _) = keeping(), let origin = session.state.origin,
      let first = held.first, !answering.contains(first.id)
    else { return }
    let downloads = DownloadStore(store: session.store, origin: origin, account: account)
    guard let kept = downloads.walk(first.id), kept.heldForZone else { return }
    let dives = downloads.dives(of: kept)
    answering.insert(kept.id)
    held.removeAll { $0.id == kept.id }
    let previous = keepingAnswer
    keepingAnswer = Task {
      await previous?.value
      let token = await session.background.begin(name: "Keeping the dives just downloaded")
      // Kept only for another try at an archive that failed: a walk with nothing left to
      // archive would come back as the same question every time.
      var failure: (any Error)?
      if let identity = dives.first?.identity, let record = kept.record {
        failure = await archive(
          dives, identity: identity, record: record, instantZone: zone,
          marked: kept.receivedBeforeAccountKnown, into: downloads)
      }
      if failure == nil { downloads.remove(walk: kept.id) }
      answering.remove(kept.id)
      reload()
      await session.background.end(token)
      if answering.isEmpty { keepingAnswer = nil }
      upload()
    }
  }

  private func next() {
    guard running == nil, !queue.isEmpty else { return }
    let queued = queue.removeFirst()
    walk = queued.walk
    runningPeripheral = queued.peripheral
    walkStarting?(queued.walk)
    running = Task {
      await run(queued.walk)
      watch?.downloadEnded(queued.peripheral)
      running = nil
      runningPeripheral = nil
      if walk === queued.walk { walk = nil }
      // After the next walk has started, so the screen sees whether one did.
      next()
      walkEnded?(queued.walk)
      upload()
    }
  }

  private func endWalks() {
    for queued in queue {
      queued.walk.outcome = .init(kind: .cancelled, sentence: DiveComputerText.cancelled)
      queued.walk.phase = .finished
      watch?.downloadEnded(queued.peripheral)
    }
    queue = []
    if let walk { cancel(walk) }
  }

  // MARK: - A walk

  private func run(_ walk: DiveComputerWalk) async {
    // However it ends, even before the computer answered.
    defer {
      let ended = walk.record ?? walk.identity.map { DiveComputerRecord(identity: $0).id }
      if let ended { walkEnds.ended(ended, at: now()) }
    }
    guard let (account, marked) = keeping(), let origin = session.state.origin else {
      finish(walk, .init(kind: .notKept, sentence: DiveComputerText.accountLoading))
      return
    }
    let store = DiveComputerStore(store: session.store, origin: origin, account: account)
    let downloads = DownloadStore(store: session.store, origin: origin, account: account)
    let all = walk.all
    // The record reaches the walk whatever its fingerprint, for the entries' sports it
    // remembers; under *Download all dives*, with no fingerprint to set.
    let lookup: @Sendable (DiveComputerFamily, String) -> DiveComputerRecord? = { family, serial in
      guard var record = store.record(family: family, serial: serial) else { return nil }
      if all { record.fingerprint = nil }
      return record
    }
    let waitingDives = downloads.waitingDives(marked: marked)
    // *Download all dives* takes again what the server answered for, and never what waits. A
    // walk before the load may be for another account than the one the server answered.
    let delivered = all || marked ? [] : downloads.allDelivered()
    let notAgain: @Sendable (DiveComputerIdentity, Data) -> Bool = { identity, fingerprint in
      let uuid = DiveComputerArchive.diveUUID(identity, fingerprint: fingerprint)
      return waitingDives.contains(uuid) || delivered.contains(uuid)
    }
    let keeper = WalkKeeper(store: downloads, marked: marked, startedAt: now())
    var watchZone: TimeZone?
    var dives: [DownloadedDive] = []
    var newest: Data?
    var skippedWaiting = 0
    var end = DiveComputerDownloadEnd(.failed(status: "DC_STATUS_IO"))
    var reportsProgress = false
    var bound = walk.watched ? nil : bounded()
    // Nothing reads *Downloading* before anything downloads: the phase moves at the listing, or
    // without one at the first progress, dive or skip.
    func walkedOne() {
      if walk.listing == nil { walk.phase = .downloading }
    }
    let events = link.download(
      walk.computer, pairedOnly: !walk.watched, lookup: lookup, waiting: notAgain,
      keep: { keeper.keep($0) })
    for await event in events {
      switch event {
      case .identified(let found):
        walk.identity = found
        // A walk nobody started pairs nothing: the computer it opened may not be the paired one.
        if walk.watched || store.record(family: found.family, serial: found.serial) != nil {
          pair(found, computer: walk.computer, store: store, marked: marked)
        }
        keeper.identified(
          record: store.record(family: found.family, serial: found.serial)?.id, zone: nil)
      case .watchZone(let zone):
        watchZone = zone
        keeper.identified(record: nil, zone: zone)
      case .busy(.reported):
        walk.computerBusy = true
      case .busy(.free):
        walk.computerBusy = false
      // Held until a dive arrives, not cleared at each retry, which another app's handshakes
      // break every ten seconds or so.
      case .busy(.otherApp):
        walk.otherAppHandshaking = true
      case .listing(let found):
        walk.listing = found
        walk.computerBusy = false
        walk.listedFromFingerprint =
          !all
          && walk.identity.flatMap { store.record(family: $0.family, serial: $0.serial) }?
            .fingerprint != nil
        if found.newDives > 0 {
          if !reportsProgress { walk.walkProgress = 0 }
          walk.phase = .downloading
        }
      case .progress(let current, let maximum):
        reportsProgress = true
        walk.walkProgress =
          maximum > 0 ? min(1, max(0, Double(current) / Double(maximum))) : nil
        if walk.listing == nil { walk.phase = .downloading }
      case .dive(let dive):
        newest = newest ?? dive.fingerprint
        dives.append(dive)
        walk.identity = walk.identity ?? dive.identity
        walk.divesDownloaded = dives.count
        walk.otherAppHandshaking = false
        if let listing = walk.listing, !reportsProgress, listing.newDives > 0 {
          walk.walkProgress = min(1, Double(dives.count) / Double(listing.newDives))
        }
        walkedOne()
        if bound != nil {
          bound?.cancel()
          bound = bounded()
        }
        diveKept?()
      case .skipped(let fingerprint):
        newest = newest ?? fingerprint
        if let identity = walk.identity,
          waitingDives.contains(DiveComputerArchive.diveUUID(identity, fingerprint: fingerprint))
        {
          skippedWaiting += 1
        }
        walkedOne()
      case .finished(let finished):
        end = finished
        if let listing = walk.listing, !reportsProgress, listing.newDives > 0 {
          walk.walkProgress = 1
        }
      }
    }
    bound?.cancel()
    let kept = keeper.kept
    if end.kind == .unpaired {
      downloads.remove(walk: kept.id)
      finish(walk, .init(kind: .unpaired, sentence: DiveComputerText.cancelled))
      return
    }
    let identity = walk.identity
    let record = identity.flatMap { store.record(family: $0.family, serial: $0.serial) }
    let advances = end.kind == .complete && end.emptyReads == 0
    let sports = walk.listing?.sports
    // Where the dives are not kept — the time-zone question cancelled, the archive not written —
    // a walk that listed still saves the record, its fingerprint unmoved.
    func rememberListed(_ identity: DiveComputerIdentity) {
      guard walk.listing != nil else { return }
      try? store.save(
        remembered(
          record, identity: identity, computer: walk.computer, sports: sports, marked: marked))
    }
    guard let identity, !dives.isEmpty else {
      downloads.remove(walk: kept.id)
      if let identity, (advances && newest != nil) || walk.listing != nil {
        var saved = remembered(
          record, identity: identity, computer: walk.computer, sports: sports, marked: marked)
        if advances, let newest {
          saved.fingerprint = newest
          downloads.clearDelivered(saved.id)
        }
        try? store.save(saved)
      }
      finish(walk, emptyHanded: end, waiting: skippedWaiting, record: all ? nil : record)
      return
    }

    var token = await session.background.begin(name: "Keeping the dives just downloaded")
    let needsZone = dives.filter { dive in
      guard case .instant(let instant)? = dive.dive?.start, dive.loggedZone == nil else {
        return false
      }
      return watchZone == nil || now().timeIntervalSince(instant) > Self.watchZoneHolds
    }
    var instantZone = watchZone
    var going = dives
    if !needsZone.isEmpty, walk.watched {
      await session.background.end(token)
      walk.suggestedZone = watchZone ?? phoneZone
      walk.phase = .askingTimeZone
      let answer = await withCheckedContinuation { zoneAnswer = $0 }
      guard let answer else {
        downloads.remove(walk: kept.id)
        rememberListed(identity)
        finish(walk, .init(kind: .cancelled, sentence: DiveComputerText.cancelled))
        return
      }
      instantZone = answer
      token = await session.background.begin(name: "Keeping the dives just downloaded")
    } else if !needsZone.isEmpty {
      let apart = Set(needsZone.map(\.fingerprint))
      going = dives.filter { !apart.contains($0.fingerprint) }
    }

    let recordID = record?.id ?? DiveComputerRecord(identity: identity).id
    let failure =
      going.isEmpty
      ? nil
      : await archive(
        going, identity: identity, record: recordID, instantZone: instantZone, marked: marked,
        into: downloads)
    let archived = failure == nil
    // The walk's record now holds only what waits for a zone, or goes.
    let heldWalk: KeptWalk? =
      walk.watched || needsZone.isEmpty
      ? nil : hold(kept, keeping: Set(needsZone.map(\.fingerprint)), in: downloads)
    if heldWalk == nil, archived { downloads.remove(walk: kept.id) }
    // Dives held for a zone are kept only where every one of them reached the disk: the
    // fingerprint passes none the phone holds nowhere.
    let heldAll =
      walk.watched || needsZone.isEmpty || heldWalk?.dives.count == needsZone.count

    let refused = dives.count(where: { $0.dive == nil })
    let parsed = dives.count - refused
    if archived {
      var saved = remembered(
        record, identity: identity, computer: walk.computer, sports: sports, marked: marked)
      if advances, heldAll, let newest {
        saved.fingerprint = newest
        saved.lastDownloaded = now()
        downloads.clearDelivered(saved.id)
      }
      try? store.save(saved)
      finish(walk, .init(kind: .kept, sentence: keptSentence(parsed, refused, end)))
    } else {
      rememberListed(identity)
      finish(
        walk,
        .init(kind: .notKept, sentence: failure.map(DiveComputerText.notWritten) ?? ""))
    }
    reload()
    if heldWalk != nil { announceHeld(downloads) }
    await session.background.end(token)
  }

  /// A walk nobody watches ends once this long passes without a dive.
  private func bounded() -> Task<Void, Never> {
    let limit = waitLimit
    return Task { [weak self] in
      try? await Task.sleep(for: limit)
      guard !Task.isCancelled else { return }
      self?.link.cancelDownload()
    }
  }

  /// Writes `dives` as one archive and keeps it in `downloads`; why not, where it was not kept.
  private func archive(
    _ dives: [DownloadedDive], identity: DiveComputerIdentity, record: String,
    instantZone: TimeZone?, marked: Bool, into downloads: DownloadStore
  ) async -> (any Error)? {
    let folder = workFolder.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let download = ComputerArchiveWriter.Download(
      identity: identity, dives: dives, moment: now(), zone: phoneZone, instantZone: instantZone)
    let writer = writer
    do {
      let written = try await Task.detached { try writer.write(download, into: folder) }.value
      _ = try downloads.add(written, record: record, marked: marked)
      return nil
    } catch {
      return error
    }
  }

  /// The walk's record cut down to the dives that wait for a zone, their bytes kept and the
  /// rest's removed.
  private func hold(_ walk: KeptWalk, keeping fingerprints: Set<Data>, in downloads: DownloadStore)
    -> KeptWalk?
  {
    var held = walk
    held.heldForZone = true
    held.dives = walk.dives.filter { Hex.data($0.fingerprint).map(fingerprints.contains) ?? false }
    guard !held.dives.isEmpty, (try? downloads.save(held)) != nil else { return nil }
    let folder = downloads.folder(of: walk.id)
    for dive in walk.dives where !held.dives.contains(dive) {
      dive.remove(from: folder)
    }
    return held
  }

  /// Saves the record of the computer just identified, so it is paired while the walk runs.
  private func pair(
    _ identity: DiveComputerIdentity, computer: FoundComputer, store: DiveComputerStore,
    marked: Bool
  ) {
    let record = store.record(family: identity.family, serial: identity.serial)
    try? store.save(
      remembered(record, identity: identity, computer: computer, sports: nil, marked: marked))
    pairingsChanged?()
  }

  /// The record as this walk leaves it, before the fingerprint moves: the identity as the
  /// computer gave it, where the phone saw it, the entries' sports.
  private func remembered(
    _ record: DiveComputerRecord?, identity: DiveComputerIdentity, computer: FoundComputer,
    sports: [NauticEntrySport]?, marked: Bool
  ) -> DiveComputerRecord {
    var kept = record ?? DiveComputerRecord(identity: identity)
    kept.vendor = identity.vendor
    kept.product = identity.product
    kept.firmware = identity.firmware ?? kept.firmware
    kept.hardware = identity.hardware ?? kept.hardware
    kept.peripheral = computer.id
    if let sports { kept.nauticSports = sports }
    kept.receivedBeforeAccountKnown = marked
    return kept
  }

  private func finish(_ walk: DiveComputerWalk, _ outcome: DiveComputerWalk.Outcome) {
    walk.outcome = outcome
    walk.phase = .finished
  }

  private func finish(
    _ walk: DiveComputerWalk, emptyHanded end: DiveComputerDownloadEnd, waiting: Int,
    record: DiveComputerRecord?
  ) {
    let counts = walk.listing.map { DiveComputerText.onComputer($0.dives) + "." }
    var outcome: DiveComputerWalk.Outcome
    switch end.kind {
    case .complete where end.notDownloaded > 0:
      // Neither *No dives* nor *No new dives*: there were, and they could not be taken.
      let sentences = [
        waiting > 0 ? DiveComputerText.alreadyWaiting(waiting) : nil,
        DiveComputerText.couldNotDownload(end.notDownloaded), counts,
      ]
      outcome = .init(
        kind: .notDownloaded, sentence: sentences.compactMap { $0 }.joined(separator: " "))
    case .complete where waiting > 0:
      let sentences = [DiveComputerText.alreadyWaiting(waiting), counts]
      outcome = .init(
        kind: .alreadyWaiting, sentence: sentences.compactMap { $0 }.joined(separator: " "))
    case .complete:
      if let record, record.fingerprint != nil || end.waiting > 0 {
        var sentence = DiveComputerText.nothingNew(
          since: record.lastDownloaded ?? now(), in: phoneZone)
        if let listing = walk.listing {
          sentence += " " + DiveComputerText.onComputer(listing.dives) + "."
        }
        outcome = .init(kind: .nothingNew, sentence: sentence)
      } else {
        outcome = .init(kind: .noDives, sentence: DiveComputerText.noDives)
      }
    case .cancelled:
      outcome = .init(kind: .cancelled, sentence: DiveComputerText.cancelled)
    case .unreachable:
      outcome = .init(kind: .failed, sentence: DiveComputerText.unreachable)
    case .failed(let status):
      outcome = .init(kind: .failed, sentence: DiveComputerText.failed(status))
    case .unpaired:
      outcome = .init(kind: .unpaired, sentence: DiveComputerText.cancelled)
    }
    if outcome.kind != .notDownloaded, end.notDownloaded > 0 {
      outcome = .init(
        kind: outcome.kind,
        sentence: outcome.sentence + " " + DiveComputerText.couldNotDownload(end.notDownloaded))
    }
    finish(walk, outcome)
  }

  private func keptSentence(_ parsed: Int, _ refused: Int, _ end: DiveComputerDownloadEnd)
    -> String
  {
    var sentence = DiveComputerText.downloaded(parsed, refused: refused)
    switch end.kind {
    case .complete, .unpaired: break
    case .cancelled: sentence = DiveComputerText.cancelled + " " + sentence
    case .unreachable: sentence = DiveComputerText.unreachable + " " + sentence
    case .failed(let status): sentence = DiveComputerText.failed(status) + " " + sentence
    }
    if end.notDownloaded > 0 {
      sentence += " " + DiveComputerText.couldNotDownload(end.notDownloaded)
    }
    return sentence
  }

  // MARK: - What an ended process left

  /// A walk an ended process left mid-way: its dives become an archive, the ones that would ask
  /// the time-zone question held apart. The fingerprint stays, the walk not having completed.
  private func recoverEndedWalks() {
    guard let origin = session.state.origin else { return }
    for downloads in DownloadStore.all(store: session.store, origin: origin) {
      for kept in downloads.walks() where !kept.heldForZone {
        let dives = downloads.dives(of: kept)
        guard let identity = dives.first?.identity, let record = kept.record else {
          downloads.remove(walk: kept.id)
          continue
        }
        let watchZone = kept.zone
        let apart = Set(
          dives.filter { dive in
            guard case .instant(let instant)? = dive.dive?.start, dive.loggedZone == nil else {
              return false
            }
            return watchZone == nil || now().timeIntervalSince(instant) > Self.watchZoneHolds
          }.map(\.fingerprint))
        let going = dives.filter { !apart.contains($0.fingerprint) }
        let folder = workFolder.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        if !going.isEmpty {
          let download = ComputerArchiveWriter.Download(
            identity: identity, dives: going, moment: kept.startedAt, zone: phoneZone,
            instantZone: watchZone)
          guard let written = try? writer.write(download, into: folder),
            (try? downloads.add(
              written, record: record, marked: kept.receivedBeforeAccountKnown)) != nil
          else { continue }
        }
        if apart.isEmpty || hold(kept, keeping: apart, in: downloads) == nil {
          downloads.remove(walk: kept.id)
        }
      }
      announceHeld(downloads)
    }
  }

  /// Each walk held for a zone that has not said so yet asks for one, once.
  private func announceHeld(_ downloads: DownloadStore) {
    for walk in downloads.walks() where walk.heldForZone && !walk.announced {
      guard let identity = walk.dives.first?.identity else { continue }
      var announced = walk
      announced.announced = true
      guard (try? downloads.save(announced)) != nil else { continue }
      notifier?.post(.timeZone(dives: walk.dives.count, from: identity.title, id: walk.id))
    }
  }

  // MARK: - Accounts

  /// The account dives are kept for now, and whether they are marked as kept before it loaded:
  /// the loaded account; while signed in before the load, the last one, marked; signed out, the
  /// last one. Nil with no server, or before any account has loaded on it.
  func keeping() -> (account: UUID, marked: Bool)? {
    guard let origin = session.state.origin else { return nil }
    if case .signedIn = session.state, session.accountLoaded, let user = session.user {
      return (user.uuid, false)
    }
    guard let last = session.store.lastAccount(for: origin) else { return nil }
    let marked = if case .signedIn = session.state { true } else { false }
    return (last, marked)
  }

  /// What was kept before the account was known stays with the account the load names: a
  /// download's dives move to it, and a computer's progress written for another is removed. A
  /// session that ended before a load clears the marks, the last account keeping them.
  func settleMarks() {
    guard let origin = session.state.origin else { return }
    switch session.state {
    case .signingIn:
      for downloads in DownloadStore.all(store: session.store, origin: origin) {
        try? downloads.clearMarks()
      }
      for computers in DiveComputerStore.all(store: session.store, origin: origin) {
        try? computers.clearMarks()
      }
    case .signedIn where session.accountLoaded:
      guard let user = session.user else { return }
      let mine = DownloadStore(store: session.store, origin: origin, account: user.uuid)
      for other in DownloadStore.all(store: session.store, origin: origin)
      where other.account != user.uuid {
        try? mine.takeMarked(from: other)
      }
      try? mine.clearMarks()
      // A computer's progress written before the load stays only with the account it was
      // written for: moved, it would carry that account's fingerprint into this one's.
      for computers in DiveComputerStore.all(store: session.store, origin: origin) {
        if computers.account == user.uuid {
          try? computers.clearMarks()
        } else {
          computers.removeMarked()
        }
      }
    default:
      break
    }
  }

  /// ``archives`` and ``held`` over what the keeping account's store holds now.
  func reload() {
    guard let (account, _) = keeping(), let origin = session.state.origin else {
      archives = []
      held = []
      return
    }
    let downloads = DownloadStore(store: session.store, origin: origin, account: account)
    archives = downloads.archives()
    held = downloads.walks().filter { $0.heldForZone && !answering.contains($0.id) }.compactMap {
      walk in
      guard let identity = walk.dives.first?.identity else { return nil }
      return HeldDives(
        id: walk.id, dives: walk.dives.count, computer: identity.title, watchZone: walk.zone)
    }
  }
}
