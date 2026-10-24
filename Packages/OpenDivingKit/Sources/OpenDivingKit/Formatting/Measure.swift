/// Every measurement the app converts between the two unit systems, keyed by dimension
/// rather than by field. Everything on the wire is metric; ``UnitSystem`` decides only
/// what a diver reads.
///
/// Deliberately absent, because they read the same in both systems: ppO₂ and surface
/// pressure (bar on every dive computer), a cylinder's volume (litres of water
/// capacity), O₂ and He percentages, CNS and OTU, coordinates and durations.
public enum Measure: Sendable, Hashable, CaseIterable {
  case depth
  case temperature
  case weight
  case pressure
  case visibility
  case altitude
  /// Surface air consumption, bar/min.
  case sac
  /// Respiratory minute volume, L/min.
  case rmv
  case gasVolume

  /// The short unit, as it follows a value: `"m"`, `"°F"`, `"psi/min"`.
  public func label(_ units: UnitSystem) -> String {
    switch (self, units) {
    case (.depth, .metric), (.visibility, .metric), (.altitude, .metric): "m"
    case (.depth, .imperial), (.visibility, .imperial), (.altitude, .imperial): "ft"
    case (.temperature, .metric): "°C"
    case (.temperature, .imperial): "°F"
    case (.weight, .metric): "kg"
    case (.weight, .imperial): "lb"
    case (.pressure, .metric): "bar"
    case (.pressure, .imperial): "psi"
    case (.sac, .metric): "bar/min"
    case (.sac, .imperial): "psi/min"
    case (.rmv, .metric): "L/min"
    case (.rmv, .imperial): "cuft/min"
    case (.gasVolume, .metric): "L"
    case (.gasVolume, .imperial): "cuft"
    }
  }

  /// The unit spoken, for VoiceOver: "ft" reads as a word and "°C" not at all.
  public func word(_ units: UnitSystem) -> String {
    switch (self, units) {
    case (.depth, .metric), (.visibility, .metric), (.altitude, .metric): "meters"
    case (.depth, .imperial), (.visibility, .imperial), (.altitude, .imperial): "feet"
    case (.temperature, .metric): "degrees Celsius"
    case (.temperature, .imperial): "degrees Fahrenheit"
    case (.weight, .metric): "kilograms"
    case (.weight, .imperial): "pounds"
    case (.pressure, .metric): "bar"
    case (.pressure, .imperial): "psi"
    case (.sac, .metric): "bar per minute"
    case (.sac, .imperial): "psi per minute"
    case (.rmv, .metric): "liters per minute"
    case (.rmv, .imperial): "cubic feet per minute"
    case (.gasVolume, .metric): "liters"
    case (.gasVolume, .imperial): "cubic feet"
    }
  }

  /// What sits between a value and its unit: nothing for a temperature, written `24°C`
  /// as the dive computers write it, and a space for everything else.
  public var separator: String {
    self == .temperature ? "" : " "
  }

  /// The metric value as it is shown in `units`; unchanged in metric. Geometric feet,
  /// not feet of seawater, for every length.
  public func toDisplay(_ metric: Double, _ units: UnitSystem) -> Double {
    guard units == .imperial else { return metric }
    switch self {
    case .depth, .visibility, .altitude: return metric / UnitFormat.metersPerFoot
    case .temperature: return metric * 9 / 5 + 32
    case .weight: return metric / UnitFormat.kgPerPound
    case .pressure, .sac: return metric * UnitFormat.psiPerBar
    case .rmv, .gasVolume: return metric / UnitFormat.litersPerCubicFoot
    }
  }

  /// The dimensions a diver types into, each with an entry-unit toggle on the form. The rest are
  /// figures the API derives and the app only shows.
  public static let entryDimensions: [Measure] = [
    .depth, .temperature, .weight, .pressure, .visibility, .altitude,
  ]

  /// The metric value behind a number shown in `units`, unrounded; unchanged in metric.
  public func toMetric(_ display: Double, _ units: UnitSystem) -> Double {
    guard units == .imperial else { return display }
    switch self {
    case .depth, .visibility, .altitude: return display * UnitFormat.metersPerFoot
    case .temperature: return (display - 32) * 5 / 9
    case .weight: return display * UnitFormat.kgPerPound
    case .pressure, .sac: return display / UnitFormat.psiPerBar
    case .rmv, .gasVolume: return display * UnitFormat.litersPerCubicFoot
    }
  }

  /// What a number typed in `units` stores, as the web commits it (`toCommittedMetric`): back to
  /// metric, then rounded — whole metres for visibility and altitude, two decimals for the rest,
  /// metric entry included. Rounded after the conversion and never before, so 98 ft commits
  /// 29.87 m and shows as 98 ft again; a whole-metre column loses a foot now and then (50 ft of
  /// visibility is 15 m, shown as 49 ft), which the web accepts too.
  public func fromDisplay(_ display: Double, _ units: UnitSystem) -> Double {
    let metric = toMetric(display, units)
    return metricDecimals == 0
      ? NumberText.round(metric) : NumberText.round(metric, decimals: 2)
  }

  /// A metric bound as the number that gates the same range in `units`, rounded inward — a
  /// minimum up, a maximum down — so a stepper never offers a value the bound refuses: −450 m
  /// is −1476 ft. Unchanged in metric.
  public func displayBound(_ metric: Double, _ units: UnitSystem, isMinimum: Bool) -> Double {
    guard units == .imperial else { return metric }
    let shown = toDisplay(metric, units)
    return isMinimum ? shown.rounded(.up) : shown.rounded(.down)
  }

  /// Fixed metric decimals, or nil for up to two with trailing zeros trimmed. Visibility
  /// and altitude are whole metres: both are integer columns.
  var metricDecimals: Int? {
    self == .visibility || self == .altitude ? 0 : nil
  }

  /// Whole numbers for everything but the rates: a whole psi/min is one significant
  /// figure, and a cubic foot is 28 litres.
  var imperialDecimals: Int {
    switch self {
    case .sac, .gasVolume: 1
    case .rmv: 2
    default: 0
    }
  }
}
