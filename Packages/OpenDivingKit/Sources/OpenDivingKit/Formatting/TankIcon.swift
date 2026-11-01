/// Which of the three tank drawings a cylinder gets, and the gas it is coloured for — the
/// same choice the web makes, so a cylinder draws alike on both.
public struct TankIcon: Hashable, Sendable {
  public enum Kind: Hashable, Sendable {
    /// One cylinder, its hose and gauge to the right.
    case single
    /// Two cylinders on a manifold.
    case twin
    /// The single mirrored: the left of a parallel pair, beside a single as its right.
    case left
  }

  /// The gas's colouring, after the medical-gas colours dive shops borrow: oxygen green all
  /// over, nitrox a green band, trimix a brown shoulder and a green base, air none.
  public enum Gas: Hashable, Sendable {
    case air, nitrox, oxygen, trimix
  }

  public var kind: Kind
  public var gas: Gas

  public init(kind: Kind, gas: Gas) {
    self.kind = kind
    self.gas = gas
  }

  /// A twin set is recorded as one cylinder of a twin-set preset's litres, and anything else,
  /// an unrecorded volume included, is a single. `left` is the dive's first cylinder flagged
  /// parallel. An unrecorded or unnameable mix draws as air.
  public init(volume: Double?, oxygen: Double?, helium: Double?, left: Bool) {
    kind = left ? .left : VolumePresets.isTwinSet(volume) ? .twin : .single
    gas = Self.gas(oxygen: oxygen, helium: helium)
  }

  static func gas(oxygen: Double?, helium: Double?) -> Gas {
    guard let oxygen, let helium, GasMath.isNameable(oxygen: oxygen, helium: helium) else {
      return .air
    }
    if helium > 0 { return .trimix }
    if oxygen >= GasMath.oxygenMinimum { return .oxygen }
    if GasMath.airOxygen.contains(oxygen) { return .air }
    return .nitrox
  }
}
