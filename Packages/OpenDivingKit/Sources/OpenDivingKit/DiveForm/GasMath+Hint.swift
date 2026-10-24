// The line under each of the form's tanks (`gasHintParts`): what the gas is, how deep it may be
// breathed, and — on a dive with one tank, where the depth it was breathed at is known — the
// depth it is equivalent to.
extension GasMath {
  /// The nitrogen in air, which an EAD is measured against.
  static let airNitrogen = 79.0

  /// The equivalent narcotic depth in metres of breathing the mix at `depth`, oxygen counted as
  /// narcotic; floored at the surface, since a helium mix in shallow water works out shallower
  /// than it. Nil without a helium figure.
  public static func endDepth(_ depth: Double, helium: Double?) -> Double? {
    guard let helium, helium.isFinite, depth.isFinite else { return nil }
    let equivalent = (depth + metersPerBar) * (1 - helium / 100) - metersPerBar
    return max(0, equivalent)
  }

  /// The equivalent air depth in metres of breathing a nitrox at `depth`, floored at the
  /// surface; nil for a mix with helium in it, which has an END instead.
  public static func ead(_ depth: Double, oxygen: Double?, helium: Double?) -> Double? {
    guard let oxygen, oxygen.isFinite, depth.isFinite else { return nil }
    guard let helium, helium.isFinite, helium <= 0 else { return nil }
    let equivalent = (depth + metersPerBar) * (100 - oxygen) / airNitrogen - metersPerBar
    return max(0, equivalent)
  }

  /// The figures under one tank, in reading order, or none while the gas cannot be named: the
  /// gas and its MOD at the limit it records or the working one; then, where `depth` is the
  /// depth it was breathed at, the END of a helium mix or the EAD of a nitrox — never for air,
  /// where both restate the depth. An impossible mix gets its spelled-out name alone.
  public static func hintParts(
    oxygen: Double?, helium: Double?, depth: Double?, ppO2: Double?, units: UnitSystem
  ) -> [String] {
    guard let name = name(oxygen: oxygen, helium: helium) else { return [] }
    var parts = [name]
    guard let oxygen, let helium, isNameable(oxygen: oxygen, helium: helium) else { return parts }

    let limit = ppO2Limit(recorded: ppO2)
    if let working = mod(oxygen: oxygen, ppO2: limit) {
      parts.append(
        "MOD \(UnitFormat.comparableDepth(working, units, floor: true)) @ ppO₂ "
          + NumberText.plain(limit))
    }

    guard let depth, depth.isFinite else { return parts }
    if helium == 0 && airOxygen.contains(oxygen) { return parts }
    let at = UnitFormat.depth(depth, units)
    if helium > 0 {
      if let end = endDepth(depth, helium: helium) {
        parts.append("END \(UnitFormat.depth(end, units, decimals: 1)) at \(at) (O₂ narcotic)")
      }
      return parts
    }
    if let equivalent = ead(depth, oxygen: oxygen, helium: helium) {
      parts.append("EAD \(UnitFormat.depth(equivalent, units, decimals: 1)) at \(at)")
    }
    return parts
  }
}
