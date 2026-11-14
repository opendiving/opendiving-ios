import Combine
@preconcurrency import CoreBluetooth
import Foundation
@preconcurrency import LibDCSwift
import OpenDivingKit

/// The Kit's ``DiveComputerLink`` over libdc-swift: Bluetooth's state and the scan from the
/// package's Core Bluetooth manager, and each download walked by a ``LibDCDeviceSession`` off
/// the main actor.
final class LibDCDiveComputerLink: DiveComputerLink {
  private let manager: CoreBluetoothManager?
  private let session: LibDCDeviceSession
  private var cancel = CancelFlag()
  private var state: (CBManagerState, CBManagerAuthorization) = (.unknown, .notDetermined)
  private var watchers: [UUID: AsyncStream<DiveComputerAvailability>.Continuation] = [:]
  private var stateSubscription: AnyCancellable?
  private var scanSubscription: AnyCancellable?
  /// Counts scans, so the stop a finished stream schedules ends its own scan and never a newer
  /// one started in the meantime.
  private var scans = 0

  /// The device's: libdc-swift's manager and the standard defaults it writes to.
  convenience init() {
    self.init(manager: .sharedManager, defaults: .standard)
  }

  /// `manager` nil leaves Bluetooth's state to ``receive(_:authorization:)`` and finds nothing,
  /// for a test.
  init(manager: CoreBluetoothManager?, defaults: UserDefaults) {
    self.manager = manager
    session = LibDCDeviceSession(defaults: defaults)
    // The manager is the central's delegate, and assigns its readiness on every state update,
    // so that assignment is when the central's state is read.
    stateSubscription = manager?.$isBluetoothReady.receive(on: DispatchQueue.main).sink {
      [weak self] _ in
      MainActor.assumeIsolated {
        guard let self, let central = self.manager?.centralManager else { return }
        self.receive(central.state, authorization: CBCentralManager.authorization)
      }
    }
  }

  var current: DiveComputerAvailability { Self.availability(state.0, state.1) }

  func availability() -> AsyncStream<DiveComputerAvailability> {
    let (stream, continuation) = AsyncStream.makeStream(of: DiveComputerAvailability.self)
    let id = UUID()
    watchers[id] = continuation
    continuation.yield(current)
    continuation.onTermination = { [weak self] _ in
      Task { @MainActor in self?.watchers[id] = nil }
    }
    return stream
  }

  /// A state the central reported.
  func receive(_ state: CBManagerState, authorization: CBManagerAuthorization) {
    let before = current
    self.state = (state, authorization)
    guard current != before else { return }
    for watcher in watchers.values { watcher.yield(current) }
  }

  static func availability(_ state: CBManagerState, _ authorization: CBManagerAuthorization)
    -> DiveComputerAvailability
  {
    if authorization == .denied || authorization == .restricted { return .refused }
    switch state {
    case .poweredOn: return .on
    case .poweredOff, .unsupported: return .off
    case .unauthorized: return .refused
    default: return .unknown
    }
  }

  func scan() -> AsyncStream<FoundComputer> {
    let (stream, continuation) = AsyncStream.makeStream(of: FoundComputer.self)
    guard let manager else {
      continuation.finish()
      return stream
    }
    scans += 1
    let scan = scans
    var yielded: Set<UUID> = []
    var cleared = false
    manager.clearDiscoveredPeripherals()
    scanSubscription = manager.$discoveredPeripherals.receive(on: DispatchQueue.main).sink {
      peripherals in
      // The manager is the process's, and its list first replays every peripheral an earlier scan
      // found, advertising or not. The clear lands later, on the main queue, as an empty list;
      // what follows it is this scan's.
      if !cleared {
        cleared = peripherals.isEmpty
        guard cleared else { return }
      }
      for peripheral in peripherals where !yielded.contains(peripheral.identifier) {
        guard let name = peripheral.name else { continue }
        yielded.insert(peripheral.identifier)
        continuation.yield(LibDCNames.found(name: name, id: peripheral.identifier))
      }
    }
    // Unfiltered: a computer already paired with the phone can advertise its name and no service,
    // which a service-filtered scan never reports. The package still admits only a stored device
    // or a name it recognises, which keeps the list to dive computers.
    manager.startScanning(omitUnsupportedPeripherals: false)
    continuation.onTermination = { [weak self] _ in
      Task { @MainActor in
        guard let self, self.scans == scan else { return }
        self.stopScan()
      }
    }
    return stream
  }

  private func stopScan() {
    scanSubscription = nil
    manager?.stopScanning()
  }

  func download(
    _ computer: FoundComputer, pairedOnly: Bool,
    lookup: @escaping @Sendable (DiveComputerFamily, String) -> DiveComputerRecord?,
    waiting: @escaping @Sendable (DiveComputerIdentity, Data) -> Bool,
    keep: @escaping @Sendable (DownloadedDive) -> Void
  ) -> AsyncStream<DiveComputerDownloadEvent> {
    let (stream, continuation) = AsyncStream.makeStream(of: DiveComputerDownloadEvent.self)
    stopScan()
    let cancel = CancelFlag()
    self.cancel = cancel
    let session = session
    session.queue.async {
      session.download(
        computer, pairedOnly: pairedOnly, cancel: cancel, lookup: lookup, waiting: waiting,
        keep: keep, into: continuation)
    }
    return stream
  }

  func cancelDownload() {
    cancel.set(true)
  }

  /// The name the computer advertises, rebuilt from its record — its product, then its serial
  /// for a family whose name carries one — which resolves it to the family and model it opens
  /// as.
  func computer(for record: DiveComputerRecord, at peripheral: UUID) -> FoundComputer {
    let name =
      record.family.advertisesSerial
      ? DiveComputerText.title(vendor: record.vendor, product: record.product) + " "
        + record.serial
      : record.product
    return LibDCNames.found(name: name, id: peripheral)
  }
}
