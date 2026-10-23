/// One line of the per-tank consumption table: a cylinder the dive logs and the share of
/// the gas the API attributed to it, or a tank the API attributed that matches none.
public struct TankGasUseRow: Hashable, Sendable {
  /// The cylinder's 1-based position, bare — the Tanks card's number for it — or the
  /// device's `Gas N` for a tank matching no cylinder.
  public var label: String
  /// The gas named as the Tanks card names it; nil where it cannot be, and for an
  /// unmatched tank.
  public var gas: String?
  /// The cylinder's role as the API sent it.
  public var role: String?
  /// Whether the cylinder records both pressures, which tells the two reasons a row has
  /// no figures apart.
  public var hasPressures: Bool
  /// Nil for a cylinder with no figures, a row worth keeping: dropping it would leave the
  /// table shorter than the Tanks card above it.
  public var use: DiveTankGasUse?

  /// The rows for a dive, in the order it lists its cylinders, then a row per tank no
  /// cylinder claimed; empty when the API attributed nothing per tank.
  ///
  /// Cylinders join tanks on `gas_number`, and a number that names two cylinders, or two
  /// tanks, names none: every tank reaches exactly one row, so the visible rows always add
  /// up to the dive-wide total (`tankGasUseRows`).
  public static func rows(mixtures: [DiveMixtureRead], gasUse: DiveGasUse?) -> [TankGasUseRow] {
    let tanks = gasUse?.tanks ?? []
    guard !tanks.isEmpty else { return [] }

    var mixtureCounts: [Int: Int] = [:]
    for number in mixtures.compactMap(\.gasNumber) { mixtureCounts[number, default: 0] += 1 }
    var tankCounts: [Int: Int] = [:]
    for tank in tanks { tankCounts[tank.gasNumber, default: 0] += 1 }
    var tankIndexByNumber: [Int: Int] = [:]
    for (index, tank) in tanks.enumerated() where tankCounts[tank.gasNumber] == 1 {
      tankIndexByNumber[tank.gasNumber] = index
    }

    var claimed = Set<Int>()
    var rows = mixtures.enumerated().map { index, mixture in
      var use: DiveTankGasUse?
      if let number = mixture.gasNumber, mixtureCounts[number] == 1,
        let tankIndex = tankIndexByNumber[number]
      {
        claimed.insert(tankIndex)
        use = tanks[tankIndex]
      }
      return TankGasUseRow(
        label: String(index + 1),
        gas: GasMath.name(oxygen: mixture.oxygen, helium: mixture.helium),
        role: mixture.role,
        hasPressures: mixture.startPressure != nil && mixture.endPressure != nil,
        use: use)
    }
    for (index, tank) in tanks.enumerated() where !claimed.contains(index) {
      rows.append(
        TankGasUseRow(
          label: "Gas \(tank.gasNumber)", gas: nil, role: nil, hasPressures: false, use: tank))
    }
    return rows
  }
}
