import Foundation

/// The upload: each archive of the loaded account, oldest first, with `POST /imports?apply=true`
/// under the archive's own key, by a running app whose account has loaded — loaded first, quietly,
/// where this process has not. One upload is in flight at a time.
///
/// **While a walk runs, its dives go up.** Once the upload before has been answered and at least
/// ``uploadFloor`` after it began, the settled dives the walk kept since its last archive are cut
/// into the next — a Suunto's one at a time, a Shearwater's several — and sent. An archive that
/// waits for another try is sent again before anything is cut after it; what the walk keeps
/// meanwhile is the archive after it. A dive the time-zone question waits for stays with the walk,
/// and what is left when the walk ends goes at once.
///
/// - An applied import: the archive leaves the phone, its dives join what the server answered
///   for, and every list over the account reads again, so each dive shows as it lands.
/// - A pending import, a server that cannot apply in one request: that import, which the
///   upload made, is discarded and the archive kept as refused. A pending answer is never taken
///   for a written dive.
/// - A 410: the import was made and has since been deleted, so the archive leaves and nothing
///   is said.
/// - Any other 4xx but a 409 and a 429: kept as refused, and not sent again by itself.
/// - A 409, a 429, a 5xx or no answer: tried again at the next occasion, as the outbox treats
///   them; with no route, iOS is left a request to the server whose completion wakes the app.
///   *Waiting to Sync* shows what the last try met.
/// - Signed out, the session's 401 among it: the archive waits for a sign-in to its account.
///
/// - The computer awaits *Which computer comes first?*: the archive stays, unsent and unsaid, with
///   no wake, until the answer has been sent.
///
/// The diver hears of a walk's archives together, once the walk has ended: at most once that its
/// dives were downloaded and wait, and, once the last of them is answered, at most once what they
/// imported — a repeat under a key answers the import the first attempt made.
extension DiveComputerEngine {
  /// The walk whose dives go up while it runs.
  struct WalkInFlight {
    let keeper: WalkKeeper
    let downloads: DownloadStore
    let store: DiveComputerStore
    /// Kept before the account loaded: its dives may yet move to another, so they go at the end.
    let marked: Bool
    var identity: DiveComputerIdentity?
    var watchZone: TimeZone?
    /// The dives kept that no archive holds yet, as walked.
    var pending: [DownloadedDive] = []
    /// The archives cut from it so far.
    var parts = 0
    /// Its computer has nothing more to give: what is left is cut by the walk's end.
    var ended = false

    var id: UUID { keeper.id }
  }

  /// What the server answered for one download's archives so far.
  struct ImportedDownload {
    var computer: String
    var rows: [LogbookImportDive] = []
    var imports: [UUID] = []
  }

  /// How long after an upload began the next may begin while a walk runs: the server answers an
  /// import faster than a Shearwater reads a dive, and each import reads the account's sites,
  /// people, gear and tags and works out its totals again.
  static let uploadFloor: TimeInterval = 30

  /// An occasion to upload: a walk's end, a launch, a route, a sign-in, the account loading,
  /// iOS completing the request left with it, *Sync now*. While a walk runs, one waits for the
  /// floor as a dive kept does.
  public func upload() {
    if inFlight?.ended == false {
      Task { await uploadWhileWalking() }
      return
    }
    startUpload()
  }

  private func startUpload() {
    guard uploading == nil else {
      uploadAgain = true
      return
    }
    isUploading = true
    uploading = Task {
      repeat {
        uploadAgain = false
        await uploadAll()
      } while uploadAgain
      uploading = nil
      isUploading = false
      if walkHasWork() { armTurn() }
    }
  }

  // MARK: - While a walk runs

  /// A dive kept, or a turn of the floor, while a walk runs: once the upload before has been
  /// answered and the floor has passed, the walk's settled dives kept since its last archive
  /// become the next archive, and the upload goes.
  func uploadWhileWalking() async {
    guard let flight = inFlight, !flight.ended, uploading == nil, cutting == nil else { return }
    guard floorPassed() else {
      armTurn()
      return
    }
    if canCut(flight) {
      let task = Task { await cut() }
      cutting = task
      await task.value
      cutting = nil
    }
    startUpload()
  }

  private func floorPassed() -> Bool {
    guard let began = lastUploadBegan else { return true }
    return now().timeIntervalSince(began) >= Self.uploadFloor
  }

  /// An archive cut now goes at once: a route, the walk's account loaded and signed in, its
  /// computer not awaiting the order's question, and no archive waiting to go before it.
  private func canCut(_ flight: WalkInFlight) -> Bool {
    guard !flight.marked, case .signedIn = session.state, session.accountLoaded,
      session.user?.uuid == flight.downloads.account, session.connectivity.isRouteAvailable,
      let origin = session.state.origin, let identity = flight.identity
    else { return false }
    let awaiting = awaitingOrder(origin: origin, account: flight.downloads.account)
    return !awaiting.contains(record(of: identity, in: flight.store))
      && sendable(flight.downloads, origin).isEmpty
  }

  /// The walk's settled dives kept since its last archive become the next. Where the archive
  /// cannot be kept, they stay with the walk for the next occasion or its end.
  private func cut() async {
    guard let flight = inFlight, let identity = flight.identity else { return }
    let going = flight.pending.filter { !waitsForZone($0, watchZone: flight.watchZone) }
    guard !going.isEmpty else { return }
    let failure = await archive(
      going, identity: identity, record: record(of: identity, in: flight.store),
      instantZone: flight.watchZone, marked: flight.marked, walk: flight.id, part: flight.parts,
      into: flight.downloads)
    guard failure == nil else { return }
    let fingerprints = Set(going.map(\.fingerprint))
    flight.keeper.archived(fingerprints)
    inFlight?.pending.removeAll { fingerprints.contains($0.fingerprint) }
    inFlight?.parts += 1
    reload()
  }

  private func record(of identity: DiveComputerIdentity, in store: DiveComputerStore) -> String {
    store.record(family: identity.family, serial: identity.serial)?.id
      ?? DiveComputerRecord(identity: identity).id
  }

  /// Something the next turn could send: an archive waiting, or settled dives to cut.
  private func walkHasWork() -> Bool {
    guard let flight = inFlight, !flight.ended, let origin = session.state.origin else {
      return false
    }
    return !sendable(flight.downloads, origin).isEmpty
      || (canCut(flight)
        && flight.pending.contains { !waitsForZone($0, watchZone: flight.watchZone) })
  }

  /// The next turn of the floor: ``uploadFloor`` after the last upload began, or after now where
  /// that has passed.
  private func armTurn() {
    guard inFlight?.ended == false else { return }
    let moment = now()
    let floorEnds = lastUploadBegan?.addingTimeInterval(Self.uploadFloor)
    let due =
      floorEnds.flatMap { $0 > moment ? $0 : nil } ?? moment.addingTimeInterval(Self.uploadFloor)
    turn?.cancel()
    let sleep = sleep
    turn = Task { [weak self] in
      guard (try? await sleep(due)) != nil, !Task.isCancelled else { return }
      self?.turn = nil
      await self?.uploadWhileWalking()
    }
  }

  // MARK: - A pass

  private func uploadAll() async {
    defer { tellImported() }
    // What a walk kept before a load it outlasted moves to the account the load named.
    if session.accountLoaded { settleMarks() }
    guard let origin = session.state.origin, let (kept, _) = keeping() else { return }
    guard case .signedIn = session.state else {
      announceSignedOut()
      return
    }
    // Before the account's load, which with no route would wait for one and fail: what waits is
    // said and iOS asked to wake the app, whatever this process has loaded.
    guard session.connectivity.isRouteAvailable else {
      waitForRoute(DownloadStore(store: session.store, origin: origin, account: kept), origin)
      return
    }
    // One assertion for the whole pass, the load included: a process iOS woke for this has no
    // other time.
    let token = await session.background.begin(name: "Importing the dives just downloaded")
    defer { Task { [session] in await session.background.end(token) } }
    if !session.accountLoaded { await loadAccount() }
    guard case .signedIn = session.state else {
      announceSignedOut()
      return
    }
    guard session.accountLoaded, let user = session.user else { return }
    settleMarks()
    await settleOrderQuestions(origin: origin, account: user.uuid)
    let downloads = DownloadStore(store: session.store, origin: origin, account: user.uuid)
    defer { reload() }
    for archive in sendable(downloads, origin) {
      guard session.connectivity.isRouteAvailable else {
        waitForRoute(downloads, origin)
        return
      }
      guard let client = try? session.requireClient() else { return }
      // The next turn sends it.
      guard inFlight?.ended != false || floorPassed() else { return }
      guard await send(archive, downloads, client, origin: origin) else { return }
    }
  }

  /// One archive's upload; whether the next goes after it.
  private func send(
    _ archive: DownloadArchive, _ downloads: DownloadStore, _ client: APIClient,
    origin: ServerOrigin
  ) async -> Bool {
    let computer = archive.summary.computers.first?.title ?? ""
    lastTries[archive.id] = nil
    lastUploadBegan = now()
    do {
      let answer = try await client.importAtOnce(
        files: [ImportFile(file: downloads.url(for: archive), filename: archive.filename)],
        idempotencyKey: archive.key)
      guard answer.isApplied else {
        noteUpload(archive, "answered with a pending import")
        try? await client.deleteImport(answer.uuid, status: "pending")
        refuse(archive, .notAppliedAtOnce, in: downloads)
        return true
      }
      noteUpload(archive, "imported")
      try? downloads.deliver(archive.dives, of: archive.record)
      downloads.remove(archive)
      if let stores = AccountStores.current(session) {
        OutboxHub.hub(for: stores.directory).listsChanged()
      }
      var download = imported[archive.group] ?? ImportedDownload(computer: computer)
      download.rows += answer.dives
      download.imports.append(answer.uuid)
      imported[archive.group] = download
      return true
    } catch let error as APIError {
      noteUpload(archive, Self.logged(error))
      switch error {
      case .http(410, _):
        downloads.remove(archive)
        return true
      case .http(let status, _) where status == 409 || status == 429 || status >= 500:
        lastTries[archive.id] = DiveComputerText.lastTry(error)
        return false
      case .http(_, let message):
        refuse(archive, .server(message: message), in: downloads)
        return true
      case .signedOut:
        announceSignedOut()
        return false
      case .unreachable:
        lastTries[archive.id] = DiveComputerText.lastTry(error)
        waitForRoute(downloads, origin)
        return false
      case .secretStore, .notAnInstance, .unreadableResponse:
        lastTries[archive.id] = DiveComputerText.lastTry(error)
        return false
      }
    } catch {
      noteUpload(archive, "failed: \(type(of: error))")
      lastTries[archive.id] = DiveComputerText.lastTry(nil)
      return false
    }
  }

  /// Each download whose archives are all answered, its walk ended, says what they imported: one
  /// with an archive still to send waits for it, and one refused or awaiting the order is left
  /// aside.
  private func tellImported() {
    guard !imported.isEmpty, let origin = session.state.origin, let downloads = keptDownloads()
    else { return }
    let unsent = Set(sendable(downloads, origin).map(\.group))
    for (download, told) in imported where download != inFlight?.id && !unsent.contains(download) {
      imported[download] = nil
      if let notice = DiveComputerNotice.imported(
        told.rows, imports: told.imports, download: download, from: told.computer,
        units: session.units)
      {
        notifier?.post(notice)
      }
    }
  }

  /// A line in the phone's watch log for each try, which names the archive and never the account.
  private func noteUpload(_ archive: DownloadArchive, _ outcome: String) {
    watch?.note("upload \(archive.id): \(outcome)")
  }

  /// The error as the log says it: its kind and status, never the server's sentence.
  private static func logged(_ error: APIError) -> String {
    switch error {
    case .http(let status, _): "answered \(status)"
    case .unreachable: "unreachable"
    case .signedOut: "signed out"
    case .notAnInstance: "not an instance"
    case .unreadableResponse: "unreadable response"
    case .secretStore: "secret store failed"
    }
  }

  private func refuse(
    _ archive: DownloadArchive, _ refusal: DownloadArchive.Refusal, in downloads: DownloadStore
  ) {
    var refused = archive
    refused.refusal = refusal
    try? downloads.save(refused)
  }

  /// No route: each download not yet announced says its dives wait, and, where any waits, iOS is
  /// left the request that wakes the app once there is one. With a route the server itself did
  /// not answer, which is neither *No internet* nor anything a wake would mend: the next
  /// occasion tries again.
  private func waitForRoute(_ downloads: DownloadStore, _ origin: ServerOrigin) {
    guard !session.connectivity.isRouteAvailable, !sendable(downloads, origin).isEmpty else {
      return
    }
    announce(downloads, origin) { dives, computer, download in
      .noInternet(dives: dives, from: computer, id: download)
    }
    wake?.leave(for: origin)
  }

  /// Nobody signed in: the archives of the account dives are kept for say they wait for a
  /// sign-in.
  private func announceSignedOut() {
    guard let (account, _) = keeping(), let origin = session.state.origin else { return }
    let downloads = DownloadStore(store: session.store, origin: origin, account: account)
    announce(downloads, origin) { dives, computer, download in
      .signedOut(dives: dives, from: computer, id: download)
    }
  }

  /// One notice for each download with an archive not yet announced, once its walk has ended,
  /// counting the dives of every archive of it that waits.
  private func announce(
    _ downloads: DownloadStore, _ origin: ServerOrigin,
    _ notice: (_ dives: Int, _ computer: String, _ download: UUID) -> DiveComputerNotice
  ) {
    let waiting = sendable(downloads, origin)
    var seen: Set<UUID> = []
    for download in waiting.map(\.group) where seen.insert(download).inserted {
      guard download != inFlight?.id else { continue }
      let archives = waiting.filter { $0.group == download }
      var saved = false
      for archive in archives where !archive.announced {
        var announced = archive
        announced.announced = true
        if (try? downloads.save(announced)) != nil { saved = true }
      }
      guard saved else { continue }
      let dives = archives.reduce(0) { $0 + $1.summary.dives }
      notifier?.post(notice(dives, archives[0].summary.computers.first?.title ?? "", download))
    }
  }

  /// The archives that go up by themselves, oldest first: not refused, and not of a computer that
  /// awaits the order's question.
  private func sendable(_ downloads: DownloadStore, _ origin: ServerOrigin) -> [DownloadArchive] {
    let awaiting = awaitingOrder(origin: origin, account: downloads.account)
    return downloads.archives().filter { $0.refusal == nil && !awaiting.contains($0.record) }
  }

  /// *Upload* on *Waiting to Sync*: a refused archive is sent again, and goes with the next
  /// occasion from now on.
  public func sendAgain(_ archive: DownloadArchive) {
    guard let downloads = keptDownloads(),
      var again = downloads.archives().first(where: {
        $0.id == archive.id
      })
    else { return }
    again.refusal = nil
    try? downloads.save(again)
    reload()
    upload()
  }

  /// Removes a download that waits from the phone, after the diver confirmed
  /// ``DiveComputerText/removeDownloadWarning``.
  public func remove(_ archive: DownloadArchive) {
    guard let downloads = keptDownloads() else { return }
    downloads.remove(archive)
    reload()
  }

  private func keptDownloads() -> DownloadStore? {
    guard let origin = session.state.origin, let (account, _) = keeping() else { return nil }
    return DownloadStore(store: session.store, origin: origin, account: account)
  }
}
