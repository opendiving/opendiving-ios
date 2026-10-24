/// The units the diver types each measurement in on this phone, where they differ from the
/// account's: a diver who thinks in metres and rents an SPG reading psi flips pressure and
/// leaves the rest. The account's `units` stays the display authority everywhere else, and what
/// reaches the wire is metric either way. An override records the system itself ("my SPG
/// reads psi"), so an account that changes its units carries every dimension not overridden.
public struct EntryUnits: Codable, Hashable, Sendable {
  /// Only the entry dimensions, and only where they differ from the account.
  public private(set) var overrides: [String: UnitSystem]

  public init() {
    overrides = [:]
  }

  /// The system `measure` is typed in, for an account whose units are `account`.
  public func units(_ measure: Measure, account: UnitSystem) -> UnitSystem {
    Self.key(measure).flatMap { overrides[$0] } ?? account
  }

  /// The toggle beside a measured field: flips that dimension to the other system, removing the
  /// override when that is the account's own.
  public mutating func toggle(_ measure: Measure, account: UnitSystem) {
    guard let key = Self.key(measure) else { return }
    let next: UnitSystem = units(measure, account: account) == .metric ? .imperial : .metric
    overrides[key] = next == account ? nil : next
  }

  /// A stored value read leniently: a dimension this build does not type into, or a system it
  /// does not know, is dropped and the rest kept.
  public init(from decoder: any Decoder) throws {
    let stored = try decoder.singleValueContainer().decode([String: String].self)
    let known = Set(Measure.entryDimensions.compactMap(Self.key))
    overrides = stored.compactMapValues(UnitSystem.init(rawValue:)).filter {
      known.contains($0.key)
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(overrides)
  }

  /// The web's key for an entry dimension, which is also what the file stores.
  static func key(_ measure: Measure) -> String? {
    switch measure {
    case .depth: "depth"
    case .temperature: "temperature"
    case .weight: "weight"
    case .pressure: "pressure"
    case .visibility: "visibility"
    case .altitude: "altitude"
    case .sac, .rmv, .gasVolume: nil
    }
  }
}
