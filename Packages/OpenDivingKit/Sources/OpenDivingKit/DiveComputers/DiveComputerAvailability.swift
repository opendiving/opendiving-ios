/// Whether the phone can use Bluetooth for the app.
public enum DiveComputerAvailability: Hashable, Sendable {
  case on
  case off
  /// The diver refused the app Bluetooth, or the device restricts it.
  case refused
  /// Core Bluetooth has not said yet.
  case unknown
}
