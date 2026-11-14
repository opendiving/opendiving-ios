import Foundation
import Observation

/// The *Dive Computers* screen's model, over the engine, its link and the phone's paired
/// computers: idle → scanning, once the diver asks to pair one → the walk the diver starts,
/// through its phases to finished, with an outcome.
///
/// **The paired computers are listed in the account's order**, each with the line its state
/// gives (``status(_:)``), and reordered on the server where it keeps one and there is a route.
/// A computer paired beside exactly one other asks *Which computer comes first?*, and its dives
/// wait for the answer.
///
/// **No route is needed**: a download on a boat is the point. What is needed is Bluetooth and an
/// account to keep the dives for.
///
/// **A connection pairs the computer**, for every server: its record is saved once the computer
/// is identified, so it is listed while the first download runs.
///
/// **The watch yields and follows**: a scan that sees a paired computer under another identifier
/// moves its record's hint there, the watch's request with it. While the screen scans, the watch
/// logs what each computer advertises.
///
/// **Dives held for a time zone are asked about** when the screen opens, the question the screen
/// asks after a walk, and the answer sends them on.
@MainActor
@Observable
public final class DiveComputerModel {
  public enum Phase: Hashable, Sendable {
    case idle, scanning, connecting, downloading, askingTimeZone, finished
  }

  public typealias Outcome = DiveComputerWalk.Outcome

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
    /// The scan's row while the computer is advertising.
    public let row: Row?

    public var id: String { record.id }
  }

  /// *Which computer comes first?*, for a computer paired beside exactly one other.
  public struct OrderQuestion: Hashable, Sendable {
    /// The computer just paired.
    public let record: DiveComputerRecord
    /// *Shearwater Perdix 3*.
    public let other: String
    public let otherSerial: String
  }

  public private(set) var availability = DiveComputerAvailability.unknown
  private var scanPhase = Phase.idle
  /// The walk the diver started here, kept for its outcome until the next scan.
  public private(set) var walk: DiveComputerWalk?
  /// The computers the latest scan found, newest-seen first.
  public private(set) var rows: [Row] = []
  /// The phone's paired computers in the account's order, those it has not placed after by
  /// title, with this account's downloads.
  public private(set) var paired: [Paired] = []
  /// The diver asked to pair a computer: the screen looks for one while Bluetooth is on.
  public private(set) var searching = false
  /// The question a computer just paired waits for, until it is answered.
  public private(set) var orderQuestion: OrderQuestion?
  /// An answer to ``orderQuestion`` is on its way.
  public private(set) var answeringOrder = false
  /// Whether iOS has asked the diver about notifications; nil until known.
  private var notificationsAsked: Bool?
  /// Why nothing may start, other than Bluetooth: no account to keep the dives for yet.
  public private(set) var refusal: String?
  /// The diver put the question about held dives aside for this visit.
  private var heldDismissed = false

  public var phase: Phase {
    if askingHeld { return .askingTimeZone }
    guard let walk else { return scanPhase }
    switch walk.phase {
    case .connecting: return .connecting
    case .downloading: return .downloading
    case .askingTimeZone: return .askingTimeZone
    case .finished: return .finished
    }
  }

  /// The question asked of dives a walk nobody watched held for a zone: shown while no walk of
  /// the diver's is in flight.
  private var askingHeld: Bool {
    !heldDismissed && !engine.held.isEmpty && walk?.isBusy != true
  }

  /// The computer being downloaded, once it identified itself.
  public var identity: DiveComputerIdentity? { walk?.identity }
  public var divesDownloaded: Int { walk?.divesDownloaded ?? 0 }
  /// libdivecomputer's progress up to 1, where the family reports it; else, after a listing, the
  /// dives downloaded over the new dives the listing named, as ``downloadingText`` counts them.
  /// Never below ``startingProgress``.
  public var progress: Double? { walk?.progress }
  /// The least of the bar, so a long first dive does not read as a download that has not begun.
  public static let startingProgress = DiveComputerWalk.startingProgress
  /// The walk's count, once the computer listed its entries.
  public var listing: DiveComputerListing? { walk?.listing }
  /// The computer last said it was busy with another app.
  public var computerBusy: Bool { walk?.computerBusy ?? false }
  /// Another app's handshake broke a transfer since the walk started or last delivered a dive.
  public var otherAppHandshaking: Bool { walk?.otherAppHandshaking ?? false }
  /// The listing counts from the stored fingerprint, rather than the whole computer.
  public var listedFromFingerprint: Bool { walk?.listedFromFingerprint ?? false }
  public var outcome: Outcome? { askingHeld ? nil : walk?.outcome }
  /// The zone the time-zone question offers first: the watch's where the walk or the held dives
  /// reported one, else the phone's.
  public var suggestedZone: TimeZone {
    if askingHeld { return engine.held.first?.watchZone ?? phoneZone }
    return walk?.suggestedZone ?? phoneZone
  }

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
  public var isBusy: Bool { walk?.isBusy ?? false }

  /// *Downloading 2 of 3 new dives* while downloading after a listing, *Downloading dive 3*
  /// without one.
  public var downloadingText: String? {
    guard phase == .downloading else { return nil }
    return walk?.downloadingText
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

  @ObservationIgnored private let engine: DiveComputerEngine
  @ObservationIgnored private let phoneZone: TimeZone
  @ObservationIgnored private var scanTask: Task<Void, Never>?
  @ObservationIgnored private var seen: [FoundComputer] = []
  @ObservationIgnored private var lastComputer: FoundComputer?
  /// A walk nobody started stopped the scan, which starts again once it ends.
  @ObservationIgnored private var resumesScan = false

  private var session: Session { engine.session }
  private var link: any DiveComputerLink { engine.link }
  private var pairedWatch: DiveComputerWatch? { engine.watch }

  /// `zone` is the phone's, which a test fixes.
  public init(engine: DiveComputerEngine, zone: TimeZone = .current) {
    self.engine = engine
    phoneZone = zone
    engine.reload()
    engine.pairingsChanged = { [weak self] in self?.rebuildRows() }
    engine.walkStarting = { [weak self] walk in
      guard let self, !walk.watched, scanTask != nil else { return }
      stopScanning()
      resumesScan = true
    }
    engine.walkEnded = { [weak self] _ in
      guard let self else { return }
      rebuildRows()
      guard resumesScan, engine.walk == nil else { return }
      resumesScan = false
      startScanning()
    }
  }

  // MARK: - Scanning

  /// Follows Bluetooth's state until cancelled: scans while it is on and nothing else is going
  /// on, and stops when it goes.
  public func watch() async {
    rebuildRows()
    for await state in link.availability() {
      availability = state
      if state == .on {
        if phase == .idle || phase == .scanning { startScanning() }
      } else {
        stopScanning()
      }
    }
  }

  /// *Pair a dive computer*: looks for computers nearby from now on, as long as the screen lasts.
  public func pair() {
    searching = true
    startScanning()
  }

  /// Starts a scan once the diver asked to pair, unless something refuses one.
  public func startScanning() {
    guard searching, availability == .on, !isBusy, !askingHeld, scanTask == nil, admits() else {
      return
    }
    scanPhase = .scanning
    walk = nil
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
    rebuildRows()
    guard phase == .scanning else { return }
    stopScanning()
    startScanning()
  }

  public func stopScanning() {
    scanTask?.cancel()
    scanTask = nil
    if scanPhase == .scanning { scanPhase = .idle }
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
    let ordered = Self.ordered(store?.records() ?? [], by: engine.order ?? [])
    paired = ordered.map { record in
      Paired(record: record, title: record.title, row: rows.first { $0.recordID == record.id })
    }
    askOrder(store)
  }

  /// `records` by their place in the account's `order`, the ones it does not hold after, as they
  /// came.
  static func ordered(_ records: [DiveComputerRecord], by order: [DiveComputerRead])
    -> [DiveComputerRecord]
  {
    let places = Dictionary(
      order.map { (DiveComputerRead.fold($0.serial), $0.position) },
      uniquingKeysWith: { first, _ in first })
    return records.enumerated().sorted { a, b in
      let left = places[DiveComputerRead.fold(a.element.serial)] ?? Int.max
      let right = places[DiveComputerRead.fold(b.element.serial)] ?? Int.max
      return (left, a.offset) < (right, b.offset)
    }.map(\.element)
  }

  // MARK: - What the list shows

  /// `record`'s one line: the walk in flight of it, the dives it waits on, else its last
  /// download and its switch.
  public func status(_ record: DiveComputerRecord) -> String {
    DiveComputerStatus.line(
      record, walk: engine.walk, archives: engine.archives, held: engine.held, in: phoneZone)
  }

  /// *Allow notifications* is shown: a computer is paired, and iOS has not asked yet.
  public var offersNotifications: Bool { notificationsAsked == false && !paired.isEmpty }

  /// The screen came into view: the account's order is read, the question a computer waits for
  /// asked again, and whether iOS has asked about notifications found out.
  public func appeared() async {
    rebuildRows()
    await engine.readOrder()
    rebuildRows()
    // The read may settle what a computer waited for.
    engine.upload()
    notificationsAsked = await engine.notifier?.hasAsked()
  }

  /// *Allow notifications*: iOS's own question.
  public func allowNotifications() async {
    guard let notifier = engine.notifier else { return }
    await notifier.ask()
    notificationsAsked = true
  }

  // MARK: - The order

  /// The list can be reordered: more than one computer, the account's order read from a server
  /// that keeps one, and a route to send it over.
  public var canReorder: Bool {
    paired.count > 1 && engine.order != nil && session.connectivity.isRouteAvailable
  }

  /// The diver moved the computers at `source` to before `destination`, as a list's move gives
  /// them: the whole order goes to the server, with every serial it knows that the phone does
  /// not keeping its place.
  public func move(from source: [Int], to destination: Int) {
    guard canReorder, let order = engine.order else { return }
    var moved = paired
    let taken = source.sorted().map { moved[$0] }
    for index in source.sorted(by: >) { moved.remove(at: index) }
    moved.insert(contentsOf: taken, at: destination - source.count(where: { $0 < destination }))
    paired = moved
    let records = moved.map(\.record)
    let onPhone = Set(records.map { DiveComputerRead.fold($0.serial) })
    var known = order.map(\.serial)
    let held = Set(known.map(DiveComputerRead.fold))
    known += records.filter { !held.contains(DiveComputerRead.fold($0.serial)) }.map(\.serial)
    let slots = known.indices.filter { onPhone.contains(DiveComputerRead.fold(known[$0])) }
    for (slot, record) in zip(slots, records) { known[slot] = record.serial }
    Task {
      await engine.setOrder(known)
      rebuildRows()
    }
  }

  /// The answer to *Which computer comes first?*: sent as the order, and then the new
  /// computer's dives go up. Unsent, the question stands.
  public func answerOrder(newFirst: Bool) async {
    guard orderQuestion != nil, !answeringOrder else { return }
    answeringOrder = true
    defer { answeringOrder = false }
    // The two serials are the whole order only once the order is read: sent unread, they
    // would replace one nobody has seen.
    if engine.order == nil, !engine.orderRouteMissing { await engine.readOrder() }
    guard engine.order != nil || engine.orderRouteMissing else { return }
    rebuildRows()
    guard let question = orderQuestion else { return }
    let serials =
      newFirst
      ? [question.record.serial, question.otherSerial]
      : [question.otherSerial, question.record.serial]
    await engine.answerOrder(serials, for: question.record)
    rebuildRows()
  }

  /// The question the first computer that awaits it asks, while exactly one other is known.
  /// Where none or several are now, it no longer stands: with none there is nothing to order,
  /// and with several the new one goes last, where the list can move it.
  private func askOrder(_ store: DiveComputerStore?) {
    guard let store, let waiting = store.records().first(where: \.awaitsOrder) else {
      orderQuestion = nil
      return
    }
    let others = engine.otherComputers(than: waiting.serial, store: store)
    guard others.count == 1, let other = others.first else {
      orderQuestion = nil
      // None known may only be the order not read yet, whose computer may be the other one:
      // the dives keep waiting until a read says so.
      guard others.count > 1 || engine.order != nil || engine.orderRouteMissing else { return }
      Task { await engine.answerOrder(nil, for: waiting) }
      return
    }
    if let record = store.records().first(where: { DiveComputerRead.fold($0.serial) == other }) {
      orderQuestion = OrderQuestion(
        record: waiting, other: record.title, otherSerial: record.serial)
    } else if let read = engine.order?.first(where: {
      DiveComputerRead.fold($0.serial) == other
    }) {
      orderQuestion = OrderQuestion(record: waiting, other: read.title, otherSerial: read.serial)
    }
  }

  /// *Forget this dive computer*, from its page: removes it for every server, and nothing on any
  /// of them. A computer the scan still sees goes back among the found ones.
  ///
  /// A computer no recording names leaves the account's order too, where the server holds its
  /// serial alone.
  public func forget(_ record: DiveComputerRecord) {
    computers()?.forget(record)
    pairedWatch?.refresh()
    rebuildRows()
    let serial = DiveComputerRead.fold(record.serial)
    guard let order = engine.order,
      order.contains(where: { DiveComputerRead.fold($0.serial) == serial && $0.isUnlabelled })
    else { return }
    let rest = order.filter { DiveComputerRead.fold($0.serial) != serial }.map(\.serial)
    Task {
      await engine.setOrder(rest)
      rebuildRows()
    }
  }

  /// *Download automatically*, on `record`'s page: the watch holds a request for it, or not.
  public func setDownloadsAutomatically(_ on: Bool, for record: DiveComputerRecord) {
    guard let store = computers(),
      var saved = store.record(family: record.family, serial: record.serial)
    else { return }
    saved.downloadsAutomatically = on
    try? store.save(saved)
    pairedWatch?.refresh()
    rebuildRows()
  }

  /// The paired computer of this record id as the phone now remembers it.
  public func record(_ id: String) -> DiveComputerRecord? {
    paired.first { $0.id == id }?.record
  }

  // MARK: - Downloading

  /// Connects to the computer a row shows and downloads what is new on it.
  public func connect(_ row: Row) {
    start(row.computer, all: false)
  }

  /// *Download new dives* or *Download all dives*, on a paired computer's page: opened under the
  /// identifier the phone last saw it under.
  public func download(_ record: DiveComputerRecord, all: Bool) {
    guard canDownload(record) else { return }
    if let peripheral = record.peripheral {
      start(link.computer(for: record, at: peripheral), all: all)
    }
  }

  /// Whether a paired computer's page can start a download of it now.
  public func canDownload(_ record: DiveComputerRecord) -> Bool {
    record.peripheral != nil && !isBusy && blocker == nil && availability == .on
  }

  /// *Download all dives*, after *No new dives*: the same computer again, with no fingerprint.
  public func downloadAll() {
    guard let lastComputer, outcome?.offersDownloadAll == true else { return }
    start(lastComputer, all: true)
  }

  /// Stops the walk between dives; the dives already downloaded go on to be imported. At the
  /// time-zone question, nothing is written, and the question about held dives is put aside.
  public func cancel() {
    if askingHeld {
      heldDismissed = true
      startScanning()
    } else if let walk {
      engine.cancel(walk)
    }
  }

  /// The diver's answer to *Which time zone were these dives in?*: for the walk's dives that
  /// logged no zone, or for the held dives the question was asked of.
  public func answerTimeZone(_ zone: TimeZone) {
    if askingHeld {
      engine.answerHeld(zone)
      startScanning()
    } else if let walk {
      engine.answerTimeZone(zone, for: walk)
    }
  }

  /// Done with the model: stops scanning and the walk in flight.
  public func close() {
    stopScanning()
    if let walk, walk.isBusy { engine.cancel(walk) }
  }

  /// Waits for the walks in flight and the upload after them.
  public func settled() async {
    await engine.settled()
  }

  private func start(_ computer: FoundComputer, all: Bool) {
    guard !isBusy, admits() else { return }
    stopScanning()
    guard let started = engine.start(computer, all: all) else {
      startScanning()
      return
    }
    lastComputer = computer
    walk = started
  }

  /// Whether a download may start, saying why not in ``refusal``.
  private func admits() -> Bool {
    refusal = engine.keeping() == nil ? DiveComputerText.accountLoading : nil
    return refusal == nil
  }

  private func computers() -> DiveComputerStore? {
    guard let origin = session.state.origin, let account = engine.keeping()?.account else {
      return nil
    }
    return DiveComputerStore(store: session.store, origin: origin, account: account)
  }
}
