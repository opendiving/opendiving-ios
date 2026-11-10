/// A vessel's recorded facts as a line of parts — `11.1 L`, `207 bar`, `Aluminium` — or none
/// where nothing is recorded (the web's `vesselFactParts`).
///
/// Facts that are a named cylinder's lead with its name in both systems: *AL80* is what the
/// cylinder is, and the number a diver reads on it. Any other vessel leads, under imperial,
/// with the cubic feet its volume holds at its working pressure; metric has no such figure.
/// The litres always follow, being what a dive's tank records.
public enum VesselFacts {
  /// Standard atmospheres in a bar.
  static let barPerAtmosphere = 1.01325

  public static func parts(
    volume: Double?, workingPressure: Double?, material: String?, units: UnitSystem
  ) -> [String] {
    var parts: [String] = []
    if let name = presetName(volume: volume, workingPressure: workingPressure, material: material) {
      parts.append(name)
    } else if units == .imperial, let volume, let workingPressure {
      parts.append(NumberText.plain(cubicFeet(volume, workingPressure)) + " cu ft")
    }
    if let volume { parts.append(NumberText.plain(volume) + " L") }
    if let workingPressure { parts.append(UnitFormat.pressure(workingPressure, units)) }
    if let material, !material.isEmpty { parts.append(RecordSheetText.cylinderMaterial(material)) }
    return parts
  }

  /// A gear item's facts.
  public static func parts(_ item: GearItemRead, units: UnitSystem) -> [String] {
    parts(
      volume: item.volume, workingPressure: item.workingPressure, material: item.material,
      units: units)
  }

  /// The name of the named cylinder the facts are, all three agreeing with it — which is what
  /// tells the HP117 from the LP95, both 15 L (`presetNameFor`).
  static func presetName(volume: Double?, workingPressure: Double?, material: String?)
    -> String?
  {
    guard let volume, let workingPressure, let material, !material.isEmpty else { return nil }
    return VolumePresets.groups.flatMap(\.presets).first { preset in
      guard let rating = preset.workingPressure, preset.imperialName != nil else { return false }
      return preset.liters == volume && preset.material == material
        && samePressureReading(rating, workingPressure)
    }?.imperialName
  }

  /// Whether two pressures read as the same whole figure in either unit: a stamp typed as 3000
  /// psi stores 206.84 bar, and the same cylinder typed as 207 bar reads 3002 psi.
  static func samePressureReading(_ a: Double, _ b: Double) -> Bool {
    [UnitSystem.metric, .imperial].contains { units in
      UnitFormat.number(a, .pressure, units, decimals: 0)
        == UnitFormat.number(b, .pressure, units, decimals: 0)
    }
  }

  /// Whole cubic feet of gas: water capacity times working pressure in atmospheres,
  /// compressibility ignored (`cylinderCubicFeet`).
  static func cubicFeet(_ liters: Double, _ bar: Double) -> Double {
    NumberText.round(liters * (bar / barPerAtmosphere) / UnitFormat.litersPerCubicFoot)
  }
}
