import Foundation

/// What the phone remembers about one dive computer for one account: who it is, where the
/// download it last finished stopped, and the zones its dives are written in. Never
/// libdivecomputer's family or model number, which the open re-derives from the name.
public struct DiveComputerRecord: Codable, Hashable, Sendable, Identifiable {
  public var family: DiveComputerFamily
  public var vendor: String
  public var product: String
  /// As the family's exports spell it.
  public var serial: String
  public var firmware: String?
  /// The Core Bluetooth identifier the phone last saw it under: a hint for the scan's rows.
  public var peripheral: UUID?
  /// For a family that logs instants: the zone the watch last reported, and the zone the diver
  /// named, which wins over the watch's.
  public var watchZone: TimeZone?
  public var diverZone: TimeZone?
  /// libdivecomputer's fingerprint of the newest dive a finished download took, and when.
  public var fingerprint: Data?
  public var lastDownloaded: Date?
  /// *Download all dives next time*: the next download sets no fingerprint.
  public var downloadAllNextTime: Bool
  /// Written while signed in before the account had loaded, into the last account's
  /// directory: removed if the load names another account.
  public var receivedBeforeAccountKnown: Bool

  public init(
    identity: DiveComputerIdentity, peripheral: UUID? = nil, watchZone: TimeZone? = nil,
    diverZone: TimeZone? = nil, fingerprint: Data? = nil, lastDownloaded: Date? = nil,
    downloadAllNextTime: Bool = false, receivedBeforeAccountKnown: Bool = false
  ) {
    family = identity.family
    vendor = identity.vendor
    product = identity.product
    serial = identity.serial
    firmware = identity.firmware
    self.peripheral = peripheral
    self.watchZone = watchZone
    self.diverZone = diverZone
    self.fingerprint = fingerprint
    self.lastDownloaded = lastDownloaded
    self.downloadAllNextTime = downloadAllNextTime
    self.receivedBeforeAccountKnown = receivedBeforeAccountKnown
  }

  /// The file it is kept in: the family and the serial, case-folded, so a lookup by a serial
  /// spelled in either case finds it.
  public var id: String { Self.name(family: family, serial: serial) }

  /// *Shearwater Perdix 3*.
  public var title: String { DiveComputerText.title(vendor: vendor, product: product) }

  /// The zone an instant from this computer is written in: the diver's where set, else the
  /// watch's as last reported.
  public var zone: TimeZone? { diverZone ?? watchZone }

  /// The fingerprint a download from it sets: none when the diver asked for everything.
  public var fingerprintToSet: Data? { downloadAllNextTime ? nil : fingerprint }

  static func name(family: DiveComputerFamily, serial: String) -> String {
    let safe = serial.uppercased().unicodeScalars.map {
      ("A"..."Z").contains($0) || ("0"..."9").contains($0) ? String($0) : "-"
    }.joined()
    return family.rawValue + "_" + safe + ".json"
  }
}
