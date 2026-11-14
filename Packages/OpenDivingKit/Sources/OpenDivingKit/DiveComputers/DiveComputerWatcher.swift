import Foundation

/// The phone's standing connection requests to paired dive computers. A protocol because the Kit
/// builds where Core Bluetooth does not: the app conforms it over a central of its own, apart from
/// libdc-swift's, and the Kit's tests over a fake. ``DiveComputerWatch`` decides what is asked.
@MainActor
public protocol DiveComputerWatcher: AnyObject {
  /// Creates the central and delivers its events to `handler` from then on: what iOS restored of
  /// a previous process's requests, then each change of Bluetooth's state, each connection and,
  /// while observed, each advertisement.
  func start(_ handler: @escaping @MainActor (DiveComputerWatchEvent) -> Void)

  /// Asks iOS to connect to the peripheral once `seconds` have passed, a whole number because iOS
  /// refuses a start delay given as a fraction. The request does not time out; it ends in
  /// ``DiveComputerWatchEvent/connected(_:)`` or
  /// ``DiveComputerWatchEvent/failedToConnect(_:reason:)``, or at once in
  /// ``DiveComputerWatchEvent/notFound(_:)`` where iOS knows no peripheral by that identifier.
  func arm(_ peripheral: UUID, after seconds: Int)

  /// Withdraws the request, or closes the connection it made, which then reports
  /// ``DiveComputerWatchEvent/disconnected(_:reason:)``.
  func disarm(_ peripheral: UUID)

  /// Reports what each peripheral nearby advertises while `observing` is true.
  func observeAdvertisements(_ observing: Bool)
}

/// What the central reported.
public enum DiveComputerWatchEvent: Hashable, Sendable {
  /// Bluetooth's state, and Core Bluetooth's own words for it, for the log.
  case state(DiveComputerAvailability, detail: String)
  /// A peripheral iOS restored to a process it launched, and what the last process left of its
  /// request.
  case restored(UUID, RestoredRequest)
  case connected(UUID)
  case failedToConnect(UUID, reason: String?)
  case disconnected(UUID, reason: String?)
  /// iOS knows no peripheral by the identifier a request named.
  case notFound(UUID)
  case advertised(DiveComputerAdvertisement)

  public enum RestoredRequest: String, Hashable, Sendable {
    case pending, connected, none
  }
}

/// One peripheral's advertisement, as the walk with the phone needs to read it.
public struct DiveComputerAdvertisement: Hashable, Sendable {
  public var peripheral: UUID
  public var name: String?
  /// What the name resolves to, where it is a dive computer's.
  public var family: DiveComputerFamily?
  public var services: [String]
  /// The first two bytes of the manufacturer data, little-endian: the Bluetooth SIG's company
  /// identifier.
  public var companyIdentifier: UInt16?
  public var connectable: Bool?

  public init(
    peripheral: UUID, name: String?, family: DiveComputerFamily?, services: [String],
    companyIdentifier: UInt16?, connectable: Bool?
  ) {
    self.peripheral = peripheral
    self.name = name
    self.family = family
    self.services = services
    self.companyIdentifier = companyIdentifier
    self.connectable = connectable
  }
}
