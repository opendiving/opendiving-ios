import Foundation

/// What the phone remembers about one dive computer as one account sees it: who it is, which is
/// the phone's, and where the account's last finished download stopped, which is the account's
/// (``DiveComputerStore``). Never libdivecomputer's family or model number, which the open
/// re-derives from the name.
public struct DiveComputerRecord: Hashable, Sendable, Identifiable {
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
  /// so a walk reads a summary only for an entry it has not met.
  public var nauticSports: [NauticEntrySport]?
  /// How fast its dives came over to this phone, from its earlier walks: what a download's time
  /// left is first reckoned from. The phone's, as the pairing is.
  public var downloadPace: DownloadPace?
  /// *Download automatically*: the phone keeps a standing connection request for it
  /// (``DiveComputerWatch``). The phone's, as the pairing is.
  public var downloadsAutomatically: Bool
  /// Written while signed in before the account had loaded, into the last account's
  /// directory: removed if the load names another account.
  public var receivedBeforeAccountKnown: Bool
  /// The account's last walk of it broke off — the computer gone or a transfer refused — or its
  /// dives could not be kept: *The last download did not finish*.
  public var lastDownloadUnfinished = false
  /// Paired beside exactly one other computer the account knows, and *Which computer comes
  /// first?* not yet answered: its dives wait on the phone, unsent, until it is.
  public var awaitsOrder = false
  /// *Which dives do you want to download?* was answered on this account, or found nothing to
  /// ask.
  public var answeredQuestion = false
  /// A walk from *Choose dives to download* set the fingerprint aside, and it stays aside until a
  /// walk completes: a walk that broke off after the choice, and any after it, still reads the
  /// whole computer for the dives chosen and not yet kept.
  public var fingerprintSetAside = false

  /// The account has neither a fingerprint nor an answer for it: a watched walk asks which dives
  /// to download, and a walk nobody watches takes none.
  public var awaitsQuestion: Bool { fingerprint == nil && !answeredQuestion }

  public init(
    identity: DiveComputerIdentity, peripheral: UUID? = nil, fingerprint: Data? = nil,
    lastDownloaded: Date? = nil, receivedBeforeAccountKnown: Bool = false,
    downloadsAutomatically: Bool = true
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
    self.downloadsAutomatically = downloadsAutomatically
  }

  init(_ computer: PairedComputer, progress: DiveComputerProgress?) {
    family = computer.family
    vendor = computer.vendor
    product = computer.product
    serial = computer.serial
    firmware = computer.firmware
    hardware = computer.hardware
    peripheral = computer.peripheral
    nauticSports = computer.nauticSports
    downloadPace = computer.downloadPace
    downloadsAutomatically = computer.downloadsAutomatically ?? true
    fingerprint = progress?.fingerprint
    lastDownloaded = progress?.lastDownloaded
    receivedBeforeAccountKnown = progress?.receivedBeforeAccountKnown ?? false
    lastDownloadUnfinished = progress?.lastDownloadUnfinished ?? false
    awaitsOrder = progress?.awaitsOrder ?? false
    answeredQuestion = progress?.answeredQuestion ?? false
    fingerprintSetAside = progress?.fingerprintSetAside ?? false
  }

  /// The file it is kept in: the family and the serial, case-folded, so a lookup by a serial
  /// spelled in either case finds it.
  public var id: String { Self.name(family: family, serial: serial) }

  /// *Shearwater Perdix 3*.
  public var title: String { DiveComputerText.title(vendor: vendor, product: product) }

  /// The family a record's ``id`` names.
  public static func family(of id: String) -> DiveComputerFamily {
    DiveComputerFamily(rawValue: String(id.prefix { $0 != "_" }))
  }

  static func name(family: DiveComputerFamily, serial: String) -> String {
    let safe = serial.uppercased().unicodeScalars.map {
      ("A"..."Z").contains($0) || ("0"..."9").contains($0) ? String($0) : "-"
    }.joined()
    return family.rawValue + "_" + safe + ".json"
  }
}
