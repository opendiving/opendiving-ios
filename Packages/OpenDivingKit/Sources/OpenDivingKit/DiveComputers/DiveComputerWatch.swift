import Foundation

/// The watch over the phone's paired dive computers, for the app's whole process from launch:
/// for each one with *Download automatically* on and a Core Bluetooth hint, a standing connection
/// request, so that iOS wakes or relaunches the app when the computer connects.
///
/// **No computer, no Bluetooth.** The watcher, and with it the central, is made only once there
/// is something to watch, a scan to observe, or a request iOS restored; a phone with nothing
/// paired never asks for Bluetooth here.
///
/// **A request that completes is closed and asked again after ``revisitDelay``**, measured from
/// the connection; so is one that fails. A download from the screen counts as a visit too.
///
/// **It yields to the diver**: while the screen downloads from a computer, no request of the
/// watch's is open to it, so libdc-swift's central is the only one connected.
///
/// **It follows the computer**: a request is keyed by the hint its record holds now, so a hint
/// that moves withdraws the old request and arms the new one.
///
/// Everything it does and hears is written to ``DiveComputerWatchLog``.
@MainActor
public final class DiveComputerWatch {
  /// How a process began.
  public enum Launch: Hashable, Sendable {
    case byUser
    /// iOS launched it in the background to restore the centrals it names.
    case byIOS(restoring: [String])
  }

  /// After a computer connected, how long until the next request to it may complete: about four
  /// looks an hour at a computer that stays connectable. libdc-swift's own revisit interval for a
  /// watch it does not stay connected to.
  public static let revisitDelay: TimeInterval = 15 * 60

  private let log: DiveComputerWatchLog
  private let pairings: () -> [DiveComputerRecord]
  private let makeWatcher: () -> (any DiveComputerWatcher)?
  private let now: () -> Date
  private var watcher: (any DiveComputerWatcher)?
  private var availability = DiveComputerAvailability.unknown
  /// The requests open, by peripheral, each with the record it was armed for.
  private var armed: [UUID: String] = [:]
  /// Connections the watch is closing, re-armed once each reports its disconnection.
  private var closing: Set<UUID> = []
  /// Connections iOS restored, closed once Bluetooth is on.
  private var restoredConnected: Set<UUID> = []
  /// Peripherals the screen is downloading from.
  private var yielded: Set<UUID> = []
  /// When each record's computer last connected, failed to, or was downloaded from the screen.
  private var visited: [String: Date] = [:]
  private var records: [String: DiveComputerRecord] = [:]
  private var recordByPeripheral: [UUID: String] = [:]
  /// iOS launched the process for a central: made whatever is paired, so the requests it
  /// restored can be withdrawn.
  private var restoring = false
  private var scanning = false
  private var advertised: Set<DiveComputerAdvertisement> = []

  /// `pairings` reads the phone's paired computers; `makeWatcher` makes the watcher, or nil while
  /// the app may not use Bluetooth.
  public init(
    log: DiveComputerWatchLog, pairings: @escaping () -> [DiveComputerRecord],
    makeWatcher: @escaping () -> (any DiveComputerWatcher)?,
    now: @escaping () -> Date = Date.init
  ) {
    self.log = log
    self.pairings = pairings
    self.makeWatcher = makeWatcher
    self.now = now
  }

  /// The process began: arms what is paired.
  public func launched(_ launch: Launch) {
    switch launch {
    case .byUser:
      log.write("launch by the user")
    case .byIOS(let restoring):
      log.write("launch by iOS, restoring \(restoring.joined(separator: ", "))")
      self.restoring = !restoring.isEmpty
    }
    refresh()
  }

  /// A line of the app's own, such as its moves between the foreground and the background.
  public func note(_ line: String) {
    log.write(line)
  }

  /// The pairings changed: a computer paired, forgotten, switched, or seen under another
  /// identifier.
  public func refresh() {
    reload()
    arm()
  }

  /// The screen is downloading from the peripheral: the watch's request to it is withdrawn.
  public func downloadStarted(_ peripheral: UUID) {
    yielded.insert(peripheral)
    refresh()
  }

  /// The screen's download ended, whatever its outcome: the request is armed again after the
  /// revisit delay.
  public func downloadEnded(_ peripheral: UUID) {
    yielded.remove(peripheral)
    reload()
    visit(peripheral)
    arm()
  }

  /// The Dive Computers screen is scanning: what each dive computer nearby advertises is logged,
  /// once per scan for each thing it advertises.
  public func scanStarted() {
    guard !scanning else { return }
    scanning = true
    advertised = []
    refresh()
    watcher?.observeAdvertisements(true)
  }

  public func scanStopped() {
    guard scanning else { return }
    scanning = false
    watcher?.observeAdvertisements(false)
  }

  // MARK: - The requests

  private func reload() {
    let read = pairings()
    for record in read {
      if let before = records[record.id]?.peripheral, let after = record.peripheral,
        before != after
      {
        log.write("moved \(record.title) from \(before.uuidString) to \(after.uuidString)")
      }
    }
    records = Dictionary(read.map { ($0.id, $0) }) { first, _ in first }
    recordByPeripheral = [:]
    for record in read {
      if let peripheral = record.peripheral { recordByPeripheral[peripheral] = record.id }
    }
  }

  private func arm() {
    let watched = records.values.filter { $0.downloadsAutomatically && $0.peripheral != nil }
    if watcher == nil {
      guard !watched.isEmpty || scanning || restoring, let made = makeWatcher() else { return }
      watcher = made
      made.start { [weak self] in self?.receive($0) }
    }
    guard let watcher, availability == .on else { return }
    var wanted: [UUID: DiveComputerRecord] = [:]
    for record in watched {
      if let peripheral = record.peripheral, !yielded.contains(peripheral) {
        wanted[peripheral] = record
      }
    }
    for (peripheral, id) in armed where wanted[peripheral]?.id != id {
      armed[peripheral] = nil
      let why = yielded.contains(peripheral) ? "a download from the screen" : "not watched"
      log.write("withdrawn \(label(peripheral)): \(why)")
      watcher.disarm(peripheral)
    }
    for (peripheral, record) in wanted.sorted(by: { $0.value.id < $1.value.id })
    where armed[peripheral] == nil && !closing.contains(peripheral) {
      let delay = remaining(record.id)
      armed[peripheral] = record.id
      log.write("armed \(label(peripheral)) after \(Int(delay)) s")
      watcher.arm(peripheral, after: delay)
    }
  }

  private func remaining(_ id: String) -> TimeInterval {
    guard let visit = visited[id] else { return 0 }
    return max(0, visit.addingTimeInterval(Self.revisitDelay).timeIntervalSince(now()).rounded())
  }

  private func visit(_ peripheral: UUID) {
    if let id = recordByPeripheral[peripheral] { visited[id] = now() }
  }

  private func label(_ peripheral: UUID) -> String {
    let title = recordByPeripheral[peripheral].flatMap { records[$0]?.title } ?? "unpaired"
    return "\(title) \(peripheral.uuidString)"
  }

  // MARK: - What the central reports

  private func receive(_ event: DiveComputerWatchEvent) {
    switch event {
    case .state(let state, let detail):
      log.write("bluetooth \(detail)")
      availability = state
      switch state {
      case .on:
        let restored = restoredConnected
        restoredConnected = []
        for peripheral in restored { completed(peripheral) }
        arm()
      case .off, .refused:
        // iOS drops every request and connection with Bluetooth.
        armed = [:]
        closing = []
      case .unknown:
        break
      }
    case .restored(let peripheral, let request):
      log.write("restored \(label(peripheral)), request \(request.rawValue)")
      switch request {
      case .pending: armed[peripheral] = recordByPeripheral[peripheral] ?? ""
      case .connected: restoredConnected.insert(peripheral)
      case .none: break
      }
    case .connected(let peripheral):
      log.write("connected \(label(peripheral))")
      restoredConnected.remove(peripheral)
      completed(peripheral)
    case .failedToConnect(let peripheral, let reason):
      log.write("failed to connect \(label(peripheral)): \(reason ?? "no reason given")")
      armed[peripheral] = nil
      visit(peripheral)
      arm()
    case .disconnected(let peripheral, let reason):
      log.write("disconnected \(label(peripheral))" + (reason.map { ": \($0)" } ?? ""))
      closing.remove(peripheral)
      armed[peripheral] = nil
      arm()
    case .notFound(let peripheral):
      // Left armed, so it is not asked again until Bluetooth comes back or the hint moves.
      log.write("not found \(label(peripheral)): iOS knows no peripheral by this identifier")
    case .advertised(let advertisement):
      guard scanning,
        advertisement.family != nil || recordByPeripheral[advertisement.peripheral] != nil,
        advertised.insert(advertisement).inserted
      else { return }
      log.write(Self.line(advertisement, pairedAs: label(advertisement.peripheral)))
    }
  }

  /// Until a download is started from it, a connection is closed at once and the request asked
  /// again after the revisit delay, from its disconnection.
  private func completed(_ peripheral: UUID) {
    guard !closing.contains(peripheral) else { return }
    armed[peripheral] = nil
    closing.insert(peripheral)
    visit(peripheral)
    log.write("closing \(label(peripheral)), the next request after \(Int(Self.revisitDelay)) s")
    watcher?.disarm(peripheral)
  }

  private static func line(_ advertisement: DiveComputerAdvertisement, pairedAs label: String)
    -> String
  {
    let name = advertisement.name.map { "\"\($0)\"" } ?? "no name"
    let services =
      advertisement.services.isEmpty ? "none" : advertisement.services.joined(separator: " ")
    let company = advertisement.companyIdentifier.map { String(format: "0x%04X", $0) } ?? "none"
    let connectable = advertisement.connectable.map { $0 ? "yes" : "no" } ?? "unknown"
    return
      "advertises \(name), \(label), services \(services), company \(company), connectable \(connectable)"
  }
}
