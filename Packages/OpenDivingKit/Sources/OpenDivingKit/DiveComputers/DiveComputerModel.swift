import Foundation
import Observation

/// The *Dive Computers* screen's model, over the link, the phone's paired computers and the
/// inbox: idle → scanning → connecting → downloading → the time-zone question, only where it
/// is needed → finished, with an outcome.
///
/// **No route is needed**: a download on a boat is the point. What is needed is Bluetooth and an
/// account to keep the archive for — the inbox's own test, the one a shared file meets — and an
/// inbox holding no full-export archive the diver shared, which would make the download's the
/// second archive of one import.
///
/// **The fingerprint advances only on a completed download that met no empty read**, to the
/// newest entry's walked — a dive's, or that of an entry skipped as no dive, so a watch's run
/// is not walked again — and only once the inbox has kept the archive holding the dives: never at
/// the walk's end, never while the time-zone question is open, so an archive not kept, or an app
/// killed at the question, leaves the record as it was and the next download walks those dives
/// again — the import's gates make the re-delivered dives links. The record is written to the
/// account the walk began from, and the fingerprint moves only when the inbox kept the archive
/// for that same account; a walk that skipped entries and delivered no dive has no archive, and
/// advances at its end while the inbox still keeps for that account.
///
/// **A connection pairs the computer**, for every server: its record is saved once the computer
/// is identified, the fingerprint aside, so it is listed while the first download runs. A walk that listed the
/// computer's entries saves it again however it ends, completed, cancelled or failed, with what
/// it learned, so the next walk reads no summary this one read.
///
/// **The watch yields and follows**: a download from the screen withdraws the watch's request to
/// that computer until it ends, and a scan that sees a paired computer under another identifier
/// moves its record's hint there, the watch's request with it. While the screen scans, the watch
/// logs what each computer advertises.
///
/// **A dive waiting in the import screen is not downloaded again**: the walk is told the dives of
/// every download archive of its mark, uploaded or not, leaves them out and does not count them
/// new.
///
/// **One download is one archive and one inbox file.** Download archives of the same mark
/// waiting to upload are replaced by the union, so a download alone never makes two that one
/// import would refuse as a second archive; an uploaded archive stays out of the union, and one
/// an import returned to waiting stays beside a newer download until the next one unites them.
/// A download never unites across a mark.
///
/// **From the walk's end to the hand-off** — the digests, the zip, the record — the model holds
/// the session's background assertion, since once the link closes no Bluetooth event keeps a
/// locked phone's app running. It ends the assertion while the time-zone question waits on the
/// diver, whose answer may take longer than an assertion lives, and takes a new one at the
/// answer.
@MainActor
@Observable
public final class DiveComputerModel {
  public enum Phase: Hashable, Sendable {
    case idle, scanning, connecting, downloading, askingTimeZone, finished
  }

  /// One computer the scan found, as its row shows it.
  public struct Row: Hashable, Sendable, Identifiable {
    public let computer: FoundComputer
    /// *Shearwater Perdix 3*.
    public let title: String
    /// *Serial D9772626 · Last downloaded 12 October*, once the phone remembers it; the serial
    /// alone where the advertised name carries one.
    public let subtitle: String?
    /// The record of the paired computer this is, where the phone remembers it.
    public let recordID: String?

    public var id: UUID { computer.id }
  }

  /// One computer the phone remembers, as *Paired Computers* shows it.
  public struct Paired: Hashable, Sendable, Identifiable {
    public let record: DiveComputerRecord
    public let title: String
    public let subtitle: String?
    /// The scan's row while the computer is advertising, which connects to it.
    public let row: Row?

    public var id: String { record.id }
  }

  /// How the screen's download ended.
  public struct Outcome: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
      /// The archive is in the inbox: the import screen follows.
      case handedOver
      /// The walk stopped at the stored fingerprint with no dive delivered.
      case nothingNew
      /// Every new dive was downloaded before and waits in the import screen.
      case alreadyWaiting
      /// The walk completed, delivering no dive, and left out entries whose download kept
      /// failing.
      case notDownloaded
      case noDives
      case cancelled
      case failed
      /// Downloaded, and kept nowhere.
      case notKept
    }

    public let kind: Kind
    public let sentence: String

    /// *Download all dives* is offered.
    public var offersDownloadAll: Bool {
      kind == .nothingNew || kind == .alreadyWaiting || kind == .notDownloaded
    }
  }

  public private(set) var availability = DiveComputerAvailability.unknown
  public private(set) var phase = Phase.idle
  /// The computers the latest scan found, newest-seen first.
  public private(set) var rows: [Row] = []
  /// The phone's paired computers, by title, with this account's downloads.
  public private(set) var paired: [Paired] = []
  /// Why nothing may start, other than Bluetooth: the account is loading, or a shared archive
  /// waits in the inbox.
  public private(set) var refusal: String?
  /// The computer being downloaded, once it identified itself.
  public private(set) var identity: DiveComputerIdentity?
  public private(set) var divesDownloaded = 0
  /// libdivecomputer's progress up to 1, where the family reports it; else, after a listing, the
  /// dives downloaded over the new dives the listing named, as ``downloadingText`` counts them.
  /// Never below ``startingProgress``.
  public var progress: Double? { walkProgress.map { max(Self.startingProgress, $0) } }
  /// The least of the bar, so a long first dive does not read as a download that has not begun.
  public static let startingProgress = 0.05
  private var walkProgress: Double?
  /// The walk's count, once the computer listed its entries.
  public private(set) var listing: DiveComputerListing?
  /// The computer last said it was busy with another app.
  public private(set) var computerBusy = false
  /// Another app's handshake broke a transfer since the walk started or last delivered a dive.
  public private(set) var otherAppHandshaking = false
  /// The listing counts from the stored fingerprint, rather than the whole computer.
  public private(set) var listedFromFingerprint = false
  public private(set) var outcome: Outcome?
  /// The zone the time-zone question offers first: the watch's where this download reported
  /// one, else the phone's.
  public private(set) var suggestedZone: TimeZone

  /// The computers found that are not paired.
  public var unpairedRows: [Row] { rows.filter { $0.recordID == nil } }

  /// What the screen shows above everything: Bluetooth's sentence, else ``refusal``.
  public var blocker: String? {
    switch availability {
    case .off: DiveComputerText.bluetoothOff
    case .refused: DiveComputerText.bluetoothRefused
    case .on, .unknown: refusal
    }
  }

  /// A download is in flight: from connecting to the time-zone question's answer.
  public var isBusy: Bool {
    phase == .connecting || phase == .downloading || phase == .askingTimeZone
  }

  /// *Downloading 2 of 3 new dives* while downloading after a listing, *Downloading dive 3*
  /// without one.
  public var downloadingText: String? {
    guard phase == .downloading else { return nil }
    guard let listing else { return DiveComputerText.downloading(max(1, divesDownloaded + 1)) }
    return DiveComputerText.downloading(
      min(divesDownloaded + 1, max(1, listing.newDives)), of: listing.newDives)
  }

  /// *3 new dives out of 11 on this computer*, or *11 dives on this computer* where the download
  /// set no fingerprint: while downloading after a listing.
  public var countsText: String? {
    guard phase == .downloading, let listing else { return nil }
    return listedFromFingerprint
      ? DiveComputerText.newOnComputer(listing.newDives, of: listing.dives)
      : DiveComputerText.onComputer(listing.dives)
  }

  /// While connecting: *Connecting* until the computer is identified, then *Reading* until the
  /// download starts.
  public var connectingText: String? {
    guard phase == .connecting else { return nil }
    return identity == nil ? DiveComputerText.connecting : DiveComputerText.reading
  }

  /// *This computer is busy…*, while connecting or downloading from a computer that is: closing
  /// other apps lets the download go on, once another app's handshake broke a transfer and until
  /// a dive arrives; else, while the computer says it is busy, the download starts when it is
  /// free, or once a dive has downloaded, continues.
  public var waitingText: String? {
    guard phase == .connecting || phase == .downloading else { return nil }
    if otherAppHandshaking { return DiveComputerText.busyOtherApp }
    guard computerBusy else { return nil }
    return divesDownloaded > 0 ? DiveComputerText.busyContinues : DiveComputerText.busy
  }

  @ObservationIgnored private let session: Session
  @ObservationIgnored private let inbox: InboxModel
  @ObservationIgnored private let link: any DiveComputerLink
  @ObservationIgnored private let pairedWatch: DiveComputerWatch?
  @ObservationIgnored private let writer: ComputerArchiveWriter
  @ObservationIgnored private let workFolder: URL
  @ObservationIgnored private let now: @Sendable () -> Date
  @ObservationIgnored private let phoneZone: TimeZone
  @ObservationIgnored private var scanTask: Task<Void, Never>?
  @ObservationIgnored private var downloadTask: Task<Void, Never>?
  @ObservationIgnored private var zoneAnswer: CheckedContinuation<TimeZone?, Never>?
  @ObservationIgnored private var seen: [FoundComputer] = []
  @ObservationIgnored private var lastComputer: FoundComputer?
  /// The diver cancelled before the link's walk began.
  @ObservationIgnored private var cancelRequested = false

  /// How long the watch's zone stands for a dive: a diver waits about a day to fly, so a dive
  /// younger than this was in the zone the watch shows now, and an older one may not have been.
  private static let watchZoneHolds: TimeInterval = 24 * 60 * 60

  /// `workFolder` is where archives are written before the inbox takes them; `now` and `zone`
  /// are the clock and the phone's zone, which a test fixes. `watch` is the app's, nil where
  /// nothing watches the paired computers.
  public init(
    session: Session, inbox: InboxModel, link: any DiveComputerLink,
    generator: ComputerArchiveWriter.Generator, watch: DiveComputerWatch? = nil,
    workFolder: URL? = nil,
    now: @escaping @Sendable () -> Date = { Date() }, zone: TimeZone = .current
  ) {
    self.session = session
    self.inbox = inbox
    self.link = link
    pairedWatch = watch
    writer = ComputerArchiveWriter(generator: generator)
    self.workFolder =
      workFolder
      ?? FileManager.default.temporaryDirectory.appendingPathComponent(
        "DiveComputerDownloads", isDirectory: true)
    self.now = now
    phoneZone = zone
    suggestedZone = zone
  }

  // MARK: - Scanning

  /// Follows Bluetooth's state until cancelled: scans while it is on and nothing else is going
  /// on, and stops when it goes.
  public func watch() async {
    rebuildRows()
    for await state in link.availability() {
      availability = state
      if state == .on {
        if phase == .idle { startScanning() }
      } else {
        stopScanning()
      }
    }
  }

  /// Starts a scan, unless something refuses one.
  public func startScanning() {
    guard availability == .on, phase == .idle || phase == .scanning || phase == .finished,
      scanTask == nil, admits()
    else { return }
    phase = .scanning
    outcome = nil
    // A row is a computer this scan saw: one an earlier scan saw may since have gone, or been
    // given a new identifier by iOS, which a computer forgotten in the Settings app is.
    seen = []
    rebuildRows()
    let stream = link.scan()
    scanTask = Task { [weak self] in
      for await computer in stream {
        self?.found(computer)
      }
    }
    pairedWatch?.scanStarted()
  }

  /// The app came back to the foreground: a scan in progress starts over, since what the diver
  /// did meanwhile, such as forgetting a computer in the Settings app, can leave a row whose
  /// identifier no longer reaches the computer.
  public func appBecameActive() {
    guard phase == .scanning else { return }
    stopScanning()
    startScanning()
  }

  public func stopScanning() {
    scanTask?.cancel()
    scanTask = nil
    if phase == .scanning { phase = .idle }
    pairedWatch?.scanStopped()
  }

  private func found(_ computer: FoundComputer) {
    // A name carrying the serial names one computer, so the same name under another identifier
    // is that computer moved, and the row under the old one is stale.
    let serial = computer.advertisedSerial
    seen.removeAll {
      $0.id == computer.id
        || (serial != nil && $0.family == computer.family && $0.advertisedSerial == serial)
    }
    seen.insert(computer, at: 0)
    follow(computer)
    rebuildRows()
  }

  /// A paired computer whose name carries its serial, seen under another identifier than its
  /// record's: the hint moves there.
  private func follow(_ computer: FoundComputer) {
    guard let store = computers(), let family = computer.family,
      let serial = computer.advertisedSerial,
      let record = store.record(family: family, serial: serial), record.peripheral != computer.id,
      (try? store.follow(record, to: computer.id)) != nil
    else { return }
    pairedWatch?.refresh()
  }

  /// The found rows over what the phone remembers, and the paired computers over what the scan
  /// sees.
  private func rebuildRows() {
    let store = computers()
    rows = seen.map { computer in
      let record = store.flatMap { store in
        computer.family.flatMap { family in
          computer.advertisedSerial.flatMap { store.record(family: family, serial: $0) }
        } ?? store.record(peripheral: computer.id)
      }
      return Row(
        computer: computer, title: record?.title ?? computer.title,
        subtitle: DiveComputerText.subtitle(
          serial: record?.serial ?? computer.advertisedSerial,
          lastDownloaded: record?.lastDownloaded, in: phoneZone),
        recordID: record?.id)
    }
    paired = (store?.records() ?? []).map { record in
      Paired(
        record: record, title: record.title,
        subtitle: DiveComputerText.subtitle(
          serial: record.serial, lastDownloaded: record.lastDownloaded, in: phoneZone),
        row: rows.first { $0.recordID == record.id })
    }
  }

  /// *Forget this dive computer*, from its page: removes it for every server, and nothing on any
  /// of them. A computer the scan still sees goes back among the found ones.
  public func forget(_ record: DiveComputerRecord) {
    computers()?.forget(record)
    pairedWatch?.refresh()
    rebuildRows()
  }

  // MARK: - Downloading

  /// Connects to the computer a row shows and downloads what is new on it.
  public func connect(_ row: Row) {
    start(row.computer, all: false)
  }

  /// *Download all dives*, after *No new dives*: the same computer again, with no fingerprint.
  public func downloadAll() {
    guard let lastComputer, outcome?.offersDownloadAll == true else { return }
    start(lastComputer, all: true)
  }

  /// Stops the walk between dives; the dives already downloaded are handed over. At the
  /// time-zone question, nothing is written.
  public func cancel() {
    switch phase {
    case .connecting, .downloading:
      cancelRequested = true
      link.cancelDownload()
    case .askingTimeZone:
      zoneAnswer?.resume(returning: nil)
      zoneAnswer = nil
    default: break
    }
  }

  /// The diver's answer to *Which time zone were these dives in?*, for this download's dives
  /// that logged no zone, and no later ones.
  public func answerTimeZone(_ zone: TimeZone) {
    zoneAnswer?.resume(returning: zone)
    zoneAnswer = nil
  }

  /// Done with the model: stops scanning and the download in flight.
  public func close() {
    stopScanning()
    cancel()
  }

  /// Waits for the download in flight.
  public func settled() async {
    while let task = downloadTask { await task.value }
  }

  private func start(_ computer: FoundComputer, all: Bool) {
    guard downloadTask == nil, admits(), let keeping = inbox.keeping,
      let origin = session.state.origin
    else { return }
    stopScanning()
    lastComputer = computer
    phase = .connecting
    identity = nil
    divesDownloaded = 0
    walkProgress = nil
    listing = nil
    computerBusy = false
    otherAppHandshaking = false
    listedFromFingerprint = false
    outcome = nil
    cancelRequested = false
    let store = DiveComputerStore(store: session.store, origin: origin, account: keeping.account)
    let archives = inbox.keptDownloads(marked: keeping.marked).compactMap(inbox.url(for:))
    pairedWatch?.downloadStarted(computer.id)
    downloadTask = Task {
      await walk(computer, all: all, store: store, waitingIn: archives)
      pairedWatch?.downloadEnded(computer.id)
      rebuildRows()
      downloadTask = nil
    }
  }

  /// Whether a download may start, saying why not in ``refusal``.
  private func admits() -> Bool {
    if inbox.keeping == nil {
      refusal = DiveComputerText.accountLoading
    } else if inbox.holdsSharedArchive {
      refusal = DiveComputerText.archiveWaiting
    } else {
      refusal = nil
    }
    return refusal == nil
  }

  private func computers() -> DiveComputerStore? {
    guard let origin = session.state.origin, let account = inbox.keeping?.account else {
      return nil
    }
    return DiveComputerStore(store: session.store, origin: origin, account: account)
  }

  private func walk(
    _ computer: FoundComputer, all: Bool, store: DiveComputerStore, waitingIn archives: [URL]
  ) async {
    // The record reaches the walk whatever its fingerprint, for the entries' sports it
    // remembers; under *Download all dives*, with no fingerprint to set.
    let lookup: @Sendable (DiveComputerFamily, String) -> DiveComputerRecord? = { family, serial in
      guard var record = store.record(family: family, serial: serial) else { return nil }
      if all { record.fingerprint = nil }
      return record
    }
    let uuids = await Task.detached {
      archives.reduce(into: Set<UUID>()) {
        $0.formUnion(DiveComputerArchive.diveUUIDs(inArchive: $1))
      }
    }.value
    let waiting: @Sendable (DiveComputerIdentity, Data) -> Bool = { identity, fingerprint in
      uuids.contains(DiveComputerArchive.diveUUID(identity, fingerprint: fingerprint))
    }
    guard !cancelRequested else {
      finish(emptyHanded: .init(.cancelled), record: nil)
      return
    }
    var watchZone: TimeZone?
    var dives: [DownloadedDive] = []
    // The walk is newest first, so the first fingerprint is the one the record advances to.
    var newest: Data?
    var end = DiveComputerDownloadEnd(.failed(status: "DC_STATUS_IO"))
    var reportsProgress = false
    // Nothing reads *Downloading* before anything downloads: the phase moves at the listing, or
    // without one at the first progress, dive or skip.
    func walkedOne() {
      if listing == nil { phase = .downloading }
    }
    for await event in link.download(computer, lookup: lookup, waiting: waiting) {
      switch event {
      case .identified(let found):
        identity = found
        pair(found, computer: computer, store: store)
      case .watchZone(let zone):
        watchZone = zone
      case .busy(.reported):
        computerBusy = true
      case .busy(.free):
        computerBusy = false
      // Held until a dive arrives, not cleared at each retry, which another app's handshakes
      // break every ten seconds or so.
      case .busy(.otherApp):
        otherAppHandshaking = true
      case .listing(let found):
        listing = found
        computerBusy = false
        listedFromFingerprint =
          !all
          && identity.flatMap { store.record(family: $0.family, serial: $0.serial) }?
            .fingerprint != nil
        if found.newDives > 0 {
          if !reportsProgress { walkProgress = 0 }
          phase = .downloading
        }
      case .progress(let current, let maximum):
        reportsProgress = true
        walkProgress = maximum > 0 ? min(1, max(0, Double(current) / Double(maximum))) : nil
        if listing == nil { phase = .downloading }
      case .dive(let dive):
        newest = newest ?? dive.fingerprint
        dives.append(dive)
        identity = identity ?? dive.identity
        divesDownloaded = dives.count
        otherAppHandshaking = false
        if let listing, !reportsProgress, listing.newDives > 0 {
          walkProgress = min(1, Double(dives.count) / Double(listing.newDives))
        }
        walkedOne()
      case .skipped(let fingerprint):
        newest = newest ?? fingerprint
        walkedOne()
      case .finished(let finished):
        end = finished
        if let listing, !reportsProgress, listing.newDives > 0 { walkProgress = 1 }
      }
    }
    let record = identity.flatMap { store.record(family: $0.family, serial: $0.serial) }
    let advances = end.kind == .complete && end.emptyReads == 0
    let sports = listing?.sports
    // Where the dives are not kept for this account — the time-zone question cancelled, the
    // archive not written or kept elsewhere — a walk that listed still saves the record, its
    // fingerprint unmoved.
    func rememberListed(_ identity: DiveComputerIdentity) {
      guard listing != nil, inbox.keeping?.account == store.account else { return }
      try? store.save(remembered(record, identity: identity, computer: computer, sports: sports))
    }
    guard let identity, !dives.isEmpty else {
      if let identity, (advances && newest != nil) || listing != nil,
        inbox.keeping?.account == store.account
      {
        var kept = remembered(record, identity: identity, computer: computer, sports: sports)
        if advances, let newest {
          kept.fingerprint = newest
        }
        try? store.save(kept)
      }
      finish(emptyHanded: end, record: all ? nil : record)
      return
    }

    var token = await session.background.begin(name: "Keeping the dives just downloaded")
    var instantZone = watchZone
    let oldestInstant = dives.compactMap { dive -> Date? in
      if case .instant(let instant)? = dive.dive?.start, dive.loggedZone == nil { return instant }
      return nil
    }.min()
    if let oldestInstant,
      watchZone == nil || now().timeIntervalSince(oldestInstant) > Self.watchZoneHolds
    {
      await session.background.end(token)
      suggestedZone = watchZone ?? phoneZone
      phase = .askingTimeZone
      let answer = await withCheckedContinuation { zoneAnswer = $0 }
      guard let answer else {
        rememberListed(identity)
        outcome = Outcome(kind: .cancelled, sentence: DiveComputerText.cancelled)
        phase = .finished
        return
      }
      instantZone = answer
      token = await session.background.begin(name: "Keeping the dives just downloaded")
    }
    defer { phase = .finished }

    let folder = workFolder.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let download = ComputerArchiveWriter.Download(
      identity: identity, dives: dives, moment: now(), zone: phoneZone, instantZone: instantZone)
    let writer = writer
    let written: ComputerArchiveWriter.Written
    do {
      written = try await Task.detached { try writer.write(download, into: folder) }.value
    } catch {
      rememberListed(identity)
      outcome = Outcome(kind: .notKept, sentence: DiveComputerText.notWritten(error))
      await session.background.end(token)
      return
    }
    let intake = await handOver(written, folder: folder)

    let refused = dives.count(where: { $0.dive == nil })
    let parsed = dives.count - refused
    switch intake {
    case .kept(let account, _) where account == store.account:
      var kept = remembered(record, identity: identity, computer: computer, sports: sports)
      if advances, let newest {
        kept.fingerprint = newest
        kept.lastDownloaded = download.moment
      }
      try? store.save(kept)
      outcome = Outcome(
        kind: .handedOver, sentence: handedOverSentence(parsed, refused, end))
    case .kept:
      rememberListed(identity)
      outcome = Outcome(
        kind: .handedOver, sentence: handedOverSentence(parsed, refused, end))
    case .notKept(let sentence):
      rememberListed(identity)
      outcome = Outcome(kind: .notKept, sentence: sentence)
    }
    await session.background.end(token)
  }

  /// Saves the record of the computer just identified, under the account rule every save keeps,
  /// so it is paired while the download runs.
  private func pair(
    _ identity: DiveComputerIdentity, computer: FoundComputer, store: DiveComputerStore
  ) {
    guard inbox.keeping?.account == store.account else { return }
    let record = store.record(family: identity.family, serial: identity.serial)
    try? store.save(remembered(record, identity: identity, computer: computer, sports: nil))
    rebuildRows()
  }

  /// The record as this walk leaves it, before the fingerprint moves: the identity as the
  /// computer gave it, where the phone saw it, the entries' sports.
  private func remembered(
    _ record: DiveComputerRecord?, identity: DiveComputerIdentity, computer: FoundComputer,
    sports: [NauticEntrySport]?
  ) -> DiveComputerRecord {
    var kept = record ?? DiveComputerRecord(identity: identity)
    kept.vendor = identity.vendor
    kept.product = identity.product
    kept.firmware = identity.firmware ?? kept.firmware
    kept.hardware = identity.hardware ?? kept.hardware
    kept.peripheral = computer.id
    if let sports { kept.nauticSports = sports }
    kept.receivedBeforeAccountKnown = inbox.keeping?.marked ?? false
    return kept
  }

  /// Gives the archive to the inbox: as one arrival, or as the union with the download
  /// archives of its mark waiting to upload, once the inbox is idle.
  private func handOver(_ written: ComputerArchiveWriter.Written, folder: URL) async
    -> InboxModel.Intake
  {
    while true {
      while inbox.phase != .idle { await inbox.settled() }
      guard let marked = inbox.keeping?.marked else {
        return .notKept(DiveComputerText.accountLoading)
      }
      let waiting = inbox.unitableDownloads(marked: marked)
      guard !waiting.isEmpty else {
        return inbox.receive([written.url], moving: true, download: written.download)
      }
      let archives =
        [(written.url, written.download)]
        + waiting.compactMap { file in
          inbox.url(for: file).flatMap { url in file.download.map { (url, $0) } }
        }
      let unionFolder = folder.appendingPathComponent("union", isDirectory: true)
      let writer = writer
      let moment = now()
      let zone = phoneZone
      let union: ComputerArchiveWriter.Written
      do {
        union = try await Task.detached {
          try writer.unite(
            archives.map { (url: $0.0, download: $0.1) }, moment: moment, zone: zone,
            into: unionFolder)
        }.value
      } catch {
        // A waiting archive this build cannot read stays as it is, and this one waits beside
        // it.
        return inbox.receive([written.url], moving: true, download: written.download)
      }
      if let intake = inbox.replaceDownloads(waiting, with: union.url, download: union.download) {
        return intake
      }
      try? FileManager.default.removeItem(at: unionFolder)
    }
  }

  private func finish(emptyHanded end: DiveComputerDownloadEnd, record: DiveComputerRecord?) {
    let counts = listing.map { DiveComputerText.onComputer($0.dives) + "." }
    switch end.kind {
    case .complete where end.notDownloaded > 0:
      // Neither *No dives* nor *No new dives*: there were, and they could not be taken.
      let sentences = [
        end.waiting > 0 ? DiveComputerText.alreadyWaiting(end.waiting) : nil,
        DiveComputerText.couldNotDownload(end.notDownloaded), counts,
      ]
      outcome = Outcome(
        kind: .notDownloaded, sentence: sentences.compactMap { $0 }.joined(separator: " "))
    case .complete where end.waiting > 0:
      let sentences = [DiveComputerText.alreadyWaiting(end.waiting), counts]
      outcome = Outcome(
        kind: .alreadyWaiting, sentence: sentences.compactMap { $0 }.joined(separator: " "))
    case .complete:
      if let record, record.fingerprint != nil {
        var sentence = DiveComputerText.nothingNew(
          since: record.lastDownloaded ?? now(), in: phoneZone)
        if let listing { sentence += " " + DiveComputerText.onComputer(listing.dives) + "." }
        outcome = Outcome(kind: .nothingNew, sentence: sentence)
      } else {
        outcome = Outcome(kind: .noDives, sentence: DiveComputerText.noDives)
      }
    case .cancelled:
      outcome = Outcome(kind: .cancelled, sentence: DiveComputerText.cancelled)
    case .unreachable:
      outcome = Outcome(kind: .failed, sentence: DiveComputerText.unreachable)
    case .failed(let status):
      outcome = Outcome(kind: .failed, sentence: DiveComputerText.failed(status))
    }
    if let outcome, outcome.kind != .notDownloaded, end.notDownloaded > 0 {
      self.outcome = Outcome(
        kind: outcome.kind,
        sentence: outcome.sentence + " " + DiveComputerText.couldNotDownload(end.notDownloaded))
    }
    phase = .finished
  }

  private func handedOverSentence(_ parsed: Int, _ refused: Int, _ end: DiveComputerDownloadEnd)
    -> String
  {
    var sentence = DiveComputerText.downloaded(parsed, refused: refused)
    switch end.kind {
    case .complete: break
    case .cancelled: sentence = DiveComputerText.cancelled + " " + sentence
    case .unreachable: sentence = DiveComputerText.unreachable + " " + sentence
    case .failed(let status): sentence = DiveComputerText.failed(status) + " " + sentence
    }
    if end.notDownloaded > 0 {
      sentence += " " + DiveComputerText.couldNotDownload(end.notDownloaded)
    }
    return sentence
  }
}
