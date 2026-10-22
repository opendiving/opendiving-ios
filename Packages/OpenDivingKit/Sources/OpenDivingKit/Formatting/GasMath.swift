/// A breathing gas's name and its maximum operating depth, and the warning a dive owes
/// when it went past one. Metres throughout; `units` reaches only the strings, and only
/// through ``UnitFormat/comparableDepth(_:_:floor:)``.
public enum GasMath {
  /// The working ppO₂ limit, in bar, and the fallback for a cylinder that records none.
  public static let workingPPO2 = 1.4
  /// The contingency ceiling reserved for a decompression stop, in bar.
  public static let decoPPO2 = 1.6
  /// Metres of seawater per bar, the round figure the API's gas arithmetic uses too.
  static let metersPerBar = 10.0
  static let airOxygen = 20.5...21.4
  static let oxygenMinimum = 99.5
  /// The margin a depth must clear a limit by to be past it: a limit round in decimal
  /// comes back a few ULPs under it (EAN28's 1.4 limit is 39.999999999999993).
  static let depthTolerance = 1e-9

  /// Whether an O₂/He pair is a breathable gas standard shorthand can name.
  public static func isNameable(oxygen: Double?, helium: Double?) -> Bool {
    guard let oxygen, let helium, oxygen.isFinite, helium.isFinite else { return false }
    return oxygen > 0 && helium >= 0 && oxygen + helium <= 100
  }

  /// What a diver calls the gas — `Air`, `Oxygen`, `EAN32`, `21/35` — rounded to whole
  /// percent; an impossible mix spelled out (`O₂ 50% / He 60%`) so it cannot pass for a
  /// real one; nil when either fraction is unrecorded.
  public static func name(oxygen: Double?, helium: Double?) -> String? {
    guard let oxygen, let helium, oxygen.isFinite, helium.isFinite else { return nil }
    guard isNameable(oxygen: oxygen, helium: helium) else {
      return "O₂ \(NumberText.plain(oxygen))% / He \(NumberText.plain(helium))%"
    }
    let wholeOxygen = NumberText.plain(NumberText.round(oxygen))
    if helium > 0 { return wholeOxygen + "/" + NumberText.plain(NumberText.round(helium)) }
    if oxygen >= oxygenMinimum { return "Oxygen" }
    if airOxygen.contains(oxygen) { return "Air" }
    return "EAN" + wholeOxygen
  }

  /// The depth in metres at which the mix reaches `ppO2` bar, `(ppO₂ ÷ (O₂ ÷ 100) − 1) ×
  /// 10`; nil for no positive oxygen to divide by, and for a mix already past its limit
  /// at the surface, where "MOD 0 m" would read as a depth it may be breathed at.
  public static func mod(oxygen: Double?, ppO2: Double = workingPPO2) -> Double? {
    guard let oxygen, oxygen.isFinite, oxygen > 0 else { return nil }
    let depth = (ppO2 / (oxygen / 100) - 1) * metersPerBar
    return depth < 0 ? nil : depth
  }

  /// The ppO₂ a cylinder's MOD is worked out at: what the dive recorded, or the working
  /// limit.
  public static func ppO2Limit(recorded: Double?) -> Double {
    guard let recorded, recorded.isFinite else { return workingPPO2 }
    return recorded
  }

  /// Two or more cylinders, every one flagged `parallel`: a set breathed together.
  public static func isParallelSet(_ cylinders: [OxygenFractions]) -> Bool {
    cylinders.count >= 2 && cylinders.allSatisfy { $0.usage == "parallel" }
  }

  /// A parallel set holding one gas — equal recorded oxygen, and equal helium with an
  /// absent one read as zero — which a warning can judge as a single cylinder.
  public static func isSingleGasParallelSet(_ cylinders: [OxygenFractions]) -> Bool {
    guard isParallelSet(cylinders), let first = cylinders.first, let oxygen = first.oxygen
    else { return false }
    return cylinders.allSatisfy {
      $0.oxygen == oxygen && ($0.helium ?? 0) == (first.helium ?? 0)
    }
  }

  /// Why this mix is a problem at `breathedDepth`, a depth it was genuinely breathed
  /// at, or nil. Past 1.6 it is the harder finding; past only 1.4 it is a planning note.
  public static func modWarning(
    _ cylinder: OxygenFractions, breathedDepth: Double?, units: UnitSystem
  ) -> String? {
    guard let breathedDepth, breathedDepth.isFinite,
      let decoLimit = mod(oxygen: cylinder.oxygen, ppO2: decoPPO2),
      let workingLimit = mod(oxygen: cylinder.oxygen, ppO2: workingPPO2)
    else { return nil }

    let depth = UnitFormat.comparableDepth(breathedDepth, units)
    let deco = NumberText.plain(decoPPO2)
    if isPast(breathedDepth, decoLimit) {
      let limit = UnitFormat.comparableDepth(decoLimit, units, floor: true)
      return "\(depth) is past this mix's \(limit) limit at ppO₂ \(deco)."
    }
    if isPast(breathedDepth, workingLimit) {
      let limit = UnitFormat.comparableDepth(workingLimit, units, floor: true)
      let working = NumberText.plain(workingPPO2)
      return "\(depth) is past this mix's \(limit) working limit (ppO₂ \(working)); it is within "
        + "the \(deco) ceiling used for decompression."
    }
    return nil
  }

  /// The oxygen-exposure warning for a whole dive, or nil. One cylinder, or a parallel
  /// set holding one gas, is judged against the dive's maximum depth directly. Otherwise
  /// which gas was breathed at the bottom is unknown, and the one sound finding is a
  /// depth that even the deepest-capable gas on board cannot reach at 1.6 — a cylinder
  /// with no usable oxygen left out of that rather than silencing it.
  public static func diveModWarning(
    _ cylinders: [OxygenFractions], maxDepth: Double?, units: UnitSystem
  ) -> String? {
    guard let maxDepth, maxDepth.isFinite, let first = cylinders.first else { return nil }
    if cylinders.count == 1 || isSingleGasParallelSet(cylinders) {
      return modWarning(first, breathedDepth: maxDepth, units: units)
    }

    let limits = cylinders.compactMap { mod(oxygen: $0.oxygen, ppO2: decoPPO2) }
    guard let deepest = limits.max(), isPast(maxDepth, deepest) else { return nil }
    let depth = UnitFormat.comparableDepth(maxDepth, units)
    let reach = UnitFormat.comparableDepth(deepest, units, floor: true)
    return "No gas logged for this dive can be breathed at \(depth) - the deepest-capable of "
      + "them reaches \(reach) at ppO₂ \(NumberText.plain(decoPPO2))."
  }

  private static func isPast(_ depth: Double, _ limit: Double) -> Bool {
    depth > limit + depthTolerance
  }
}
