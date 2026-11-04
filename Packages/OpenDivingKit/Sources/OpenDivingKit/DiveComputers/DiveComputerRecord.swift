import Foundation

/// What the phone remembers about one dive computer for one account: who it is and where the
/// download it last finished stopped. Never libdivecomputer's family or model number, which the
/// open re-derives from the name.
public struct DiveComputerRecord: Codable, Hashable, Sendable, Identifiable {
  public var family: DiveComputerFamily
  public var vendor: String
  public var product: String
  /// As the family's exports spell it.
  public var serial: String
  public var firmware: String?
  /// Nil until a walk reads it, which a family's walk may never do.
  public var hardware: String?
  /// The Core Bluetooth identifier the phone last saw it under: a hint for the scan's rows.
  public var peripheral: UUID?
  /// libdivecomputer's fingerprint of the newest dive a finished download took, and when.
  public var fingerprint: Data?
  public var lastDownloaded: Date?
  /// For the Nautic family: the sport each logbook entry's summary named when it was last listed,
  /// so a walk reads a summary only for an entry it has not met. Optional so that a record
  /// written before it existed still decodes.
  public var nauticSports: [NauticEntrySport]?
  /// Written while signed in before the account had loaded, into the last account's
  /// directory: removed if the load names another account.
  public var receivedBeforeAccountKnown: Bool

  public init(
    identity: DiveComputerIdentity, peripheral: UUID? = nil, fingerprint: Data? = nil,
    lastDownloaded: Date? = nil, receivedBeforeAccountKnown: Bool = false
  ) {
    family = identity.family
    vendor = identity.vendor
    product = identity.product
    serial = identity.serial
    firmware = identity.firmware
    hardware = identity.hardware
    self.peripheral = peripheral
    self.fingerprint = fingerprint
    self.lastDownloaded = lastDownloaded
    self.receivedBeforeAccountKnown = receivedBeforeAccountKnown
  }

  /// The file it is kept in: the family and the serial, case-folded, so a lookup by a serial
  /// spelled in either case finds it.
  public var id: String { Self.name(family: family, serial: serial) }

  /// *Shearwater Perdix 3*.
  public var title: String { DiveComputerText.title(vendor: vendor, product: product) }

  static func name(family: DiveComputerFamily, serial: String) -> String {
    let safe = serial.uppercased().unicodeScalars.map {
      ("A"..."Z").contains($0) || ("0"..."9").contains($0) ? String($0) : "-"
    }.joined()
    return family.rawValue + "_" + safe + ".json"
  }
}
