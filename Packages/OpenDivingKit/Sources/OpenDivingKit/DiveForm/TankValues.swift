/// One tank as the dive form holds it: metric, nil for a box left blank, and `0` a value — an end
/// pressure of 0 is a drained cylinder, not a missing reading.
public struct TankValues: Codable, Hashable, Sendable {
  /// Litres of water capacity, in both unit systems.
  public var volume: Double?
  /// Bar.
  public var startPressure: Double?
  public var endPressure: Double?
  /// Percent. Nil is not recorded, never 21.
  public var oxygen: Double?
  /// Percent. Nil is not recorded, never 0.
  public var helium: Double?
  /// Bar.
  public var po2Limit: Double?
  /// The label an imported file gave the cylinder. No input writes it; it rides along.
  public var gasNumber: Int?
  public var role: String?
  public var usage: String?
  /// The diver's cylinder this tank is: the link, which is what is sent.
  public var cylinder: RecordRef?
  /// The linked cylinder as last read, for its name and its capacity; never sent, and counted
  /// only while it is the item ``cylinder`` names.
  public var vessel: GearItemInfo?

  public init(
    volume: Double? = nil, startPressure: Double? = nil, endPressure: Double? = nil,
    oxygen: Double? = nil, helium: Double? = nil, po2Limit: Double? = nil, gasNumber: Int? = nil,
    role: String? = nil, usage: String? = nil, cylinder: RecordRef? = nil,
    vessel: GearItemInfo? = nil
  ) {
    self.volume = volume
    self.startPressure = startPressure
    self.endPressure = endPressure
    self.oxygen = oxygen
    self.helium = helium
    self.po2Limit = po2Limit
    self.gasNumber = gasNumber
    self.role = role
    self.usage = usage
    self.cylinder = cylinder
    self.vessel = vessel
  }

  /// What *Add tank* appends, the web's `DEFAULT_MIXTURE`: 11.1 L of air, no vessel.
  public static let added = TankValues(volume: 11.1, oxygen: 21, helium: 0)

  /// A tank as a dive read records it.
  public init(_ mixture: DiveMixtureRead) {
    self.init(
      volume: mixture.volume, startPressure: mixture.startPressure,
      endPressure: mixture.endPressure, oxygen: mixture.oxygen, helium: mixture.helium,
      po2Limit: mixture.po2Limit, gasNumber: mixture.gasNumber, role: mixture.role,
      usage: mixture.usage, cylinder: mixture.gearItem?.ref, vessel: mixture.gearItem)
  }

  /// The cylinder a tank links, while the read item is the one the link names.
  public var linkedVessel: GearItemInfo? {
    guard let cylinder, let vessel, vessel.ref == cylinder else { return nil }
    return vessel
  }

  /// Whether the Volume box is read-only: the link stands to a vessel recording a capacity.
  public var isVolumeFromVessel: Bool { linkedVessel?.volume != nil }

  /// The volume the box shows and a save sends: the tank's own figure wherever it has one, else
  /// the linked vessel's (`tankVolume`).
  public var shownVolume: Double? { volume ?? linkedVessel?.volume }

  /// Links the tank to a cylinder picked for it, copying the vessel's capacity as the web's
  /// pick does; nil unlinks it and keeps the volume.
  public mutating func link(_ item: GearItemInfo?) {
    cylinder = item?.ref
    vessel = item
    if let capacity = item?.volume { volume = capacity }
  }

  /// The tank as a write sends it, `normalizeMixtures`: no `id`, the shown volume.
  public var write: DiveMixtureWrite {
    DiveMixtureWrite(
      volume: shownVolume, startPressure: startPressure, endPressure: endPressure,
      oxygen: oxygen, helium: helium, po2Limit: po2Limit, gasNumber: gasNumber, role: role,
      usage: usage, gearItem: cylinder)
  }

  /// The value a column holds when it is empty: nil, except helium, whose empty value is the
  /// `0` hiding the column claims — a diver who hides He dives air and nitrox.
  static func emptyValue(of column: DiveFormField) -> Double? {
    column == .mixtureHelium ? 0 : nil
  }

  /// Empties one `mixture.` column of this tank.
  mutating func clear(_ column: DiveFormField) {
    switch column {
    case .mixtureCylinder:
      cylinder = nil
      vessel = nil
    case .mixturePo2Limit: po2Limit = nil
    case .mixtureHelium: helium = 0
    case .mixtureStartPressure: startPressure = nil
    case .mixtureEndPressure: endPressure = nil
    case .mixtureUsage: usage = nil
    case .mixtureRole: role = nil
    default: break
    }
  }

  /// Whether the column holds something the reveal rule shows: a value, other than the `0`
  /// hiding helium writes.
  func reveals(_ column: DiveFormField) -> Bool {
    switch column {
    case .mixtureCylinder: cylinder != nil
    case .mixturePo2Limit: po2Limit != nil
    case .mixtureHelium: helium != nil && helium != 0
    case .mixtureStartPressure: startPressure != nil
    case .mixtureEndPressure: endPressure != nil
    case .mixtureUsage: usage != nil
    case .mixtureRole: role != nil
    default: false
    }
  }
}

extension TankValues: RewritesLocalRefs {
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    cylinder.rewrite(rewrite)
    if let ref = vessel?.ref {
      if let next = rewrite(ref) {
        vessel?.ref = next
      } else {
        vessel = nil
      }
    }
  }
}
