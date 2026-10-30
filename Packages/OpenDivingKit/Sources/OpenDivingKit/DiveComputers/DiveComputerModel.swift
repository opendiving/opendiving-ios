import Foundation
import Observation

/// The *Dive computer* screen's model, over the link, the account's remembered computers and
/// the inbox: idle → scanning → connecting → downloading → the time-zone question, only where it
/// is needed → finished, with an outcome.
///
/// **No route is needed**: a download on a boat is the point. What is needed is Bluetooth and an
/// account to keep the archive for — the inbox's own test, the one a shared file meets — and an
/// inbox holding no full-export archive the diver shared, which would make the download's the
/// second archive of one import.
///
/// **The fingerprint advances only on a completed download that met no empty read**, to the
/// newest dive's, and only once the inbox has kept the archive holding those dives: never at
/// the walk's end, never while the time-zone question is open, so an archive not kept, or an app
/// killed at the question, leaves the record as it was and the next download walks those dives
/// again — the import's gates make the re-delivered dives links. The record is written to the
/// account the walk began from, and only when the inbox kept the archive for that same account.
///
/// **One download is one archive and one inbox file.** Download archives of the same mark
/// already waiting are replaced by the union, so the inbox never holds two that one import
/// would refuse as a second archive; a download never unites across a mark.
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

    public var id: UUID { computer.id }
  }

  /// How the screen's download ended.
  public struct Outcome: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
      /// The archive is in the inbox: the import screen follows.
      case handedOver
      /// The walk stopped at the stored fingerprint with no dive delivered.
      case nothingNew
      case noDives
      case cancelled
      case failed
      /// Downloaded, and kept nowhere.
      case notKept
    }

    public let kind: Kind
    public let sentence: String

    /// *Download all dives* is offered.
    public var offersDownloadAll: Bool { kind == .nothingNew }
  }

  public private(set) var availability = DiveComputerAvailability.unknown
  public private(set) var phase = Phase.idle
  /// The computers found, newest-seen first.
  public private(set) var rows: [Row] = []
  /// Why nothing may start, other than Bluetooth: the account is loading, or a shared archive
  /// waits in the inbox.
  public private(set) var refusal: String?
  /// The computer being downloaded, once it identified itself.
  public private(set) var identity: DiveComputerIdentity?
  public private(set) var divesDownloaded = 0
  /// libdivecomputer's progress from 0 to 1, where the family reports it.
  public private(set) var progress: Double?
  public private(set) var outcome: Outcome?
  /// The zone the time-zone question offers first: the phone's.
  public let suggestedZone: TimeZone

  /// What the screen shows above everything: Bluetooth's sentence, else ``refusal``.
  public var blocker: String? {
    switch availability {
    case .off: DiveComputerText.bluetoothOff
    case .refused: DiveComputerText.bluetoothRefused
    case .on, .unknown: refusal
    }
  }

  /// *Downloading dive 3*, while downloading.
  public var downloadingText: String? {
    phase == .downloading ? DiveComputerText.downloading(max(1, divesDownloaded + 1)) : nil
  }

  @ObservationIgnored private let session: Session
  @ObservationIgnored private let inbox: InboxModel
  @ObservationIgnored private let link: any DiveComputerLink
  @ObservationIgnored private let writer: ComputerArchiveWriter
  @ObservationIgnored private let workFolder: URL
  @ObservationIgnored private let now: @Sendable () -> Date
  @ObservationIgnored private var scanTask: Task<Void, Never>?
  @ObservationIgnored private var downloadTask: Task<Void, Never>?
  @ObservationIgnored private var zoneAnswer: CheckedContinuation<TimeZone?, Never>?
  @ObservationIgnored private var seen: [FoundComputer] = []
  @ObservationIgnored private var lastComputer: FoundComputer?

  /// `workFolder` is where archives are written before the inbox takes them; `now` and `zone`
  /// are the clock and the phone's zone, which a test fixes.
  public init(
    session: Session, inbox: InboxModel, link: any DiveComputerLink,
    generator: ComputerArchiveWriter.Generator, workFolder: URL? = nil,
    now: @escaping @Sendable () -> Date = { Date() }, zone: TimeZone = .current
  ) {
    self.session = session
    self.inbox = inbox
    self.link = link
    writer = ComputerArchiveWriter(generator: generator)
    self.workFolder =
      workFolder
      ?? FileManager.default.temporaryDirectory.appendingPathComponent(
        "DiveComputerDownloads", isDirectory: true)
    self.now = now
    suggestedZone = zone
  }

  // MARK: - Scanning

  /// Follows Bluetooth's state until cancelled: scans while it is on and nothing else is going
  /// on, and stops when it goes.
  public func watch() async {
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
    let stream = link.scan()
    scanTask = Task { [weak self] in
      for await computer in stream {
        self?.found(computer)
      }
    }
  }

  public func stopScanning() {
    scanTask?.cancel()
    scanTask = nil
    if phase == .scanning { phase = .idle }
  }

  private func found(_ computer: FoundComputer) {
    seen.removeAll { $0.id == computer.id }
    seen.insert(computer, at: 0)
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
          lastDownloaded: record?.lastDownloaded, in: suggestedZone))
    }
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
    case .connecting, .downloading: link.cancelDownload()
    case .askingTimeZone:
      zoneAnswer?.resume(returning: nil)
      zoneAnswer = nil
    default: break
    }
  }

  /// The diver's answer to *Which time zone were these dives in?*, kept as theirs for the
  /// computer.
  public func answerTimeZone(_ zone: TimeZone) {
    zoneAnswer?.resume(returning: zone)
    zoneAnswer = nil
  }

  /// Leaves the screen: stops scanning and closes the connection.
  public func close() {
    stopScanning()
    cancel()
    link.disconnect()
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
    progress = nil
    outcome = nil
    let store = DiveComputerStore(store: session.store, origin: origin, account: keeping.account)
    downloadTask = Task {
      await walk(computer, all: all, store: store)
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

  private func walk(_ computer: FoundComputer, all: Bool, store: DiveComputerStore) async {
    let lookup: @Sendable (DiveComputerFamily, String) -> DiveComputerRecord? = { family, serial in
      guard !all, let record = store.record(family: family, serial: serial),
        record.fingerprintToSet != nil
      else { return nil }
      return record
    }
    var watchZone: TimeZone?
    var dives: [DownloadedDive] = []
    var end = DiveComputerDownloadEnd(.failed(status: "DC_STATUS_IO"))
    for await event in link.download(computer, lookup: lookup) {
      switch event {
      case .identified(let found):
        identity = found
        phase = .downloading
      case .watchZone(let zone):
        watchZone = zone
      case .progress(let current, let maximum):
        progress = maximum > 0 ? min(1, max(0, Double(current) / Double(maximum))) : nil
      case .dive(let dive):
        dives.append(dive)
        identity = identity ?? dive.identity
        divesDownloaded = dives.count
        phase = .downloading
      case .finished(let finished):
        end = finished
      }
    }
    let family = identity?.family ?? computer.family
    let record = identity.flatMap { store.record(family: $0.family, serial: $0.serial) }
    guard let identity, !dives.isEmpty else {
      finish(emptyHanded: end, family: family, record: all ? nil : record)
      return
    }

    var token = await session.background.begin(name: "Keeping the dives just downloaded")
    var diverZone = record?.diverZone
    let needsZone = dives.contains {
      if case .instant? = $0.dive?.start { return true }
      return false
    }
    if needsZone, diverZone == nil, watchZone == nil {
      await session.background.end(token)
      phase = .askingTimeZone
      let answer = await withCheckedContinuation { zoneAnswer = $0 }
      guard let answer else {
        outcome = Outcome(kind: .cancelled, sentence: DiveComputerText.cancelled)
        phase = .finished
        return
      }
      diverZone = answer
      token = await session.background.begin(name: "Keeping the dives just downloaded")
    }
    defer { phase = .finished }

    let folder = workFolder.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let download = ComputerArchiveWriter.Download(
      identity: identity, dives: dives, moment: now(), zone: suggestedZone,
      instantZone: diverZone ?? watchZone)
    let writer = writer
    let written: ComputerArchiveWriter.Written
    do {
      written = try await Task.detached { try writer.write(download, into: folder) }.value
    } catch {
      outcome = Outcome(kind: .notKept, sentence: DiveComputerText.notWritten(error))
      await session.background.end(token)
      return
    }
    let intake = await handOver(written, folder: folder)

    let refused = dives.count(where: { $0.dive == nil })
    let parsed = dives.count - refused
    switch intake {
    case .kept(let account, _) where account == store.account:
      let advances = end.kind == .complete && end.emptyReads == 0
      var kept = record ?? DiveComputerRecord(identity: identity)
      kept.vendor = identity.vendor
      kept.product = identity.product
      kept.firmware = identity.firmware ?? kept.firmware
      kept.peripheral = computer.id
      if let watchZone { kept.watchZone = watchZone }
      kept.diverZone = diverZone
      if advances, let newest = dives.first {
        kept.fingerprint = newest.fingerprint
        kept.lastDownloaded = download.moment
        kept.downloadAllNextTime = false
      }
      kept.receivedBeforeAccountKnown = inbox.keeping?.marked ?? false
      try? store.save(kept)
      outcome = Outcome(
        kind: .handedOver, sentence: handedOverSentence(parsed, refused, end))
    case .kept:
      outcome = Outcome(
        kind: .handedOver, sentence: handedOverSentence(parsed, refused, end))
    case .notKept(let sentence):
      outcome = Outcome(kind: .notKept, sentence: sentence)
    }
    await session.background.end(token)
  }

  /// Gives the archive to the inbox: as one arrival, or as the union with the download
  /// archives of its mark already waiting, once the inbox is idle.
  private func handOver(_ written: ComputerArchiveWriter.Written, folder: URL) async
    -> InboxModel.Intake
  {
    while true {
      while inbox.phase != .idle { await inbox.settled() }
      guard let marked = inbox.keeping?.marked else {
        return .notKept(DiveComputerText.accountLoading)
      }
      let waiting = inbox.waitingDownloads(marked: marked)
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
      let zone = suggestedZone
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

  private func finish(
    emptyHanded end: DiveComputerDownloadEnd, family: DiveComputerFamily?,
    record: DiveComputerRecord?
  ) {
    switch end.kind {
    case .complete:
      if let record, record.fingerprintToSet != nil {
        outcome = Outcome(
          kind: .nothingNew,
          sentence: DiveComputerText.nothingNew(
            since: record.lastDownloaded ?? now(), in: suggestedZone))
      } else {
        outcome = Outcome(kind: .noDives, sentence: DiveComputerText.noDives)
      }
    case .cancelled:
      outcome = Outcome(kind: .cancelled, sentence: DiveComputerText.cancelled)
    case .unreachable:
      outcome = Outcome(
        kind: .failed, sentence: failureSentence(DiveComputerText.unreachable, family: family))
    case .failed(let status):
      outcome = Outcome(
        kind: .failed, sentence: failureSentence(DiveComputerText.failed(status), family: family))
    }
    phase = .finished
  }

  private func failureSentence(_ stopped: String, family: DiveComputerFamily?) -> String {
    family == .suuntoNautic ? DiveComputerText.suuntoAppConnected + " " + stopped : stopped
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
    return sentence
  }
}
