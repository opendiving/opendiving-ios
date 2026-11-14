@preconcurrency import CoreBluetooth
import Foundation
import OpenDivingKit

/// The Kit's ``DiveComputerWatcher`` over a central of the app's own, beside libdc-swift's: that
/// one is its own delegate and forwards nothing. Its restore identifier is what lets iOS relaunch
/// the app when a request completes after the process has ended.
final class CoreBluetoothDiveComputerWatcher: NSObject, DiveComputerWatcher {
  static let restoreIdentifier = "app.opendiving.dive-computer-watch"

  private var central: CBCentralManager?
  private var handler: (@MainActor (DiveComputerWatchEvent) -> Void)?
  /// Held, as Core Bluetooth requires of a peripheral it is asked to connect.
  private var peripherals: [UUID: CBPeripheral] = [:]
  private var observing = false

  /// A watcher where the app may use Bluetooth, or where iOS launched it to restore this central;
  /// nil otherwise, so that the watch never raises the Bluetooth prompt.
  static func make(restoring: Bool) -> CoreBluetoothDiveComputerWatcher? {
    guard restoring || CBManager.authorization == .allowedAlways else { return nil }
    return CoreBluetoothDiveComputerWatcher()
  }

  func start(_ handler: @escaping @MainActor (DiveComputerWatchEvent) -> Void) {
    self.handler = handler
    central = CBCentralManager(
      delegate: self, queue: .main,
      options: [
        CBCentralManagerOptionRestoreIdentifierKey: Self.restoreIdentifier,
        CBCentralManagerOptionShowPowerAlertKey: false,
      ])
  }

  func arm(_ peripheral: UUID, after seconds: Int) {
    guard let central, central.state == .poweredOn else { return }
    guard
      let found = peripherals[peripheral]
        ?? central.retrievePeripherals(withIdentifiers: [peripheral]).first
    else {
      handler?(.notFound(peripheral))
      return
    }
    peripherals[peripheral] = found
    // An integer NSNumber: iOS fails a request whose start delay is a floating-point one, of any
    // value, at once.
    central.connect(
      found,
      options: seconds > 0
        ? [CBConnectPeripheralOptionStartDelayKey: NSNumber(value: seconds)] : nil)
  }

  func disarm(_ peripheral: UUID) {
    guard let central, central.state == .poweredOn, let found = peripherals[peripheral] else {
      return
    }
    central.cancelPeripheralConnection(found)
  }

  func observeAdvertisements(_ observing: Bool) {
    self.observing = observing
    guard let central, central.state == .poweredOn else { return }
    if observing {
      central.scanForPeripherals(withServices: nil)
    } else {
      central.stopScan()
    }
  }

  private static func detail(_ state: CBManagerState) -> String {
    let words: String =
      switch state {
      case .poweredOn: "poweredOn"
      case .poweredOff: "poweredOff"
      case .resetting: "resetting"
      case .unauthorized: "unauthorized"
      case .unsupported: "unsupported"
      case .unknown: "unknown"
      @unknown default: "state \(state.rawValue)"
      }
    return "\(words), authorization \(CBManager.authorization.rawValue)"
  }

  private static func request(_ state: CBPeripheralState)
    -> DiveComputerWatchEvent.RestoredRequest
  {
    switch state {
    case .connecting: .pending
    case .connected: .connected
    default: .none
    }
  }

  /// The company identifier is the manufacturer data's first two bytes, little-endian.
  private nonisolated static func company(_ data: Data?) -> UInt16? {
    guard let data, data.count >= 2 else { return nil }
    let bytes = [UInt8](data.prefix(2))
    return UInt16(bytes[0]) | UInt16(bytes[1]) << 8
  }
}

// The central's queue is the main queue, so each callback runs on the main actor.
extension CoreBluetoothDiveComputerWatcher: CBCentralManagerDelegate {
  nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
    MainActor.assumeIsolated {
      let state = central.state
      if state != .poweredOn { peripherals = [:] }
      if state == .poweredOn, observing { central.scanForPeripherals(withServices: nil) }
      handler?(
        .state(
          LibDCDiveComputerLink.availability(state, CBManager.authorization),
          detail: Self.detail(state)))
    }
  }

  nonisolated func centralManager(
    _ central: CBCentralManager, willRestoreState dict: [String: Any]
  ) {
    // Delivered on the main queue, where the peripherals stay.
    nonisolated(unsafe) let restored =
      dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
    MainActor.assumeIsolated {
      for peripheral in restored {
        peripherals[peripheral.identifier] = peripheral
        handler?(.restored(peripheral.identifier, Self.request(peripheral.state)))
      }
    }
  }

  nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral)
  {
    let id = peripheral.identifier
    MainActor.assumeIsolated { handler?(.connected(id)) }
  }

  nonisolated func centralManager(
    _ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?
  ) {
    let id = peripheral.identifier
    let reason = error?.localizedDescription
    MainActor.assumeIsolated { handler?(.failedToConnect(id, reason: reason)) }
  }

  nonisolated func centralManager(
    _ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
    error: (any Error)?
  ) {
    let id = peripheral.identifier
    let reason = error?.localizedDescription
    MainActor.assumeIsolated { handler?(.disconnected(id, reason: reason)) }
  }

  nonisolated func centralManager(
    _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any], rssi: NSNumber
  ) {
    let id = peripheral.identifier
    let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name
    let services =
      ((advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? [])
      + (advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID] ?? []))
      .map(\.uuidString)
    let company = Self.company(advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data)
    let connectable = (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue
    MainActor.assumeIsolated {
      handler?(
        .advertised(
          DiveComputerAdvertisement(
            peripheral: id, name: name, family: name.flatMap { LibDCNames.resolve($0)?.family },
            services: services, companyIdentifier: company, connectable: connectable)))
    }
  }
}
