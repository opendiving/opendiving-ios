/// One series a dive profile can carry, keyed by the API's name for it. The order of
/// ``allCases`` is the order the chart plots, lists in its legend and reads out — the
/// surface gradient factor ahead of the gradient factor at depth.
public enum ProfileChannel: String, Sendable, Hashable, CaseIterable {
  case depth
  case ceiling
  case temperature
  case pressure
  /// What the diver's wrist sensor or strap read, a measurement like depth and temperature:
  /// drawn under the depth plot only because that plot's edges are taken.
  case heartRate = "heart_rate"
  case ndl
  case tts
  case ppo2
  case cns
  case surfaceGradientFactor = "surface_gradient_factor"
  case gradientFactor = "gradient_factor"

  public var label: String {
    switch self {
    case .depth: "Depth"
    case .ceiling: "Deco ceiling"
    case .temperature: "Temperature"
    case .pressure: "Tank pressure"
    case .heartRate: "Heart rate"
    case .ndl: "No-deco time"
    case .tts: "Time to surface"
    case .ppo2: "ppO₂"
    case .cns: "CNS"
    case .surfaceGradientFactor: "Surface gradient factor"
    case .gradientFactor: "Gradient factor at depth"
    }
  }

  /// What the wire's integer values are divided by to reach the display unit: the API's
  /// own scale for depth, the ceiling, temperature and pressure, and 60 for the no-deco
  /// limit and time to surface, which arrive in seconds and read in minutes. Heart rate
  /// arrives in whole beats per minute.
  public var scale: Int {
    switch self {
    case .depth, .ceiling, .temperature, .ppo2: 100
    case .pressure, .cns: 10
    case .ndl, .tts: 60
    case .heartRate, .surfaceGradientFactor, .gradientFactor: 1
    }
  }

  /// The decimals a metric reading is quoted to: the resolution it is stored at.
  /// Temperature's two are narrowed per recording to the grain its readings carry.
  public var decimals: Int {
    switch self {
    case .depth, .ceiling, .cns: 1
    case .temperature, .ppo2: 2
    case .pressure, .heartRate, .ndl, .tts, .surfaceGradientFactor, .gradientFactor: 0
    }
  }

  /// The measure the channel converts as, or nil for those that read the same in both
  /// systems. The ceiling is a depth, so it converts exactly as depth does and stays on
  /// the water it bounds.
  public var measure: Measure? {
    switch self {
    case .depth, .ceiling: .depth
    case .temperature: .temperature
    case .pressure: .pressure
    default: nil
    }
  }

  /// The metric unit.
  public var unit: String {
    switch self {
    case .depth, .ceiling: "m"
    case .temperature: "°C"
    case .pressure, .ppo2: "bar"
    case .heartRate: "bpm"
    case .ndl, .tts: "min"
    case .cns, .surfaceGradientFactor, .gradientFactor: "%"
    }
  }

  /// What sits between a reading and its unit: attached for a degree and a percent,
  /// spaced for everything else.
  public var separator: String {
    if let measure { return measure.separator }
    return unit == "%" ? "" : " "
  }

  /// Depth grows downward, so its axis — and the ceiling's, which shares it — is drawn
  /// upside down.
  public var isInverted: Bool {
    self == .depth || self == .ceiling
  }

  /// The ceiling is the one computed curve on the depth plot, and is dashed.
  public var isDashed: Bool {
    self == .ceiling
  }

  /// A gap in the ceiling means no obligation existed, which is a fact about the dive;
  /// everywhere else it means nothing was recorded.
  public var gapsAreMeaningful: Bool {
    self == .ceiling
  }

  /// The unit spoken, for VoiceOver.
  public func word(_ units: UnitSystem) -> String {
    if let measure { return measure.word(units) }
    switch self {
    case .heartRate: return "beats per minute"
    case .ndl, .tts: return "minutes"
    case .ppo2: return "bar"
    default: return "percent"
    }
  }

  /// The channel as it is labelled and quoted in `units`: unchanged in metric, and for
  /// the channels with no measure in both systems; otherwise the imperial unit at no decimals,
  /// a foot and a psi each being finer than the tenth the metric reading is stored at.
  public func display(_ units: UnitSystem) -> ChannelDisplay {
    guard units == .imperial, let measure else {
      return ChannelDisplay(channel: self, unit: unit, decimals: decimals)
    }
    return ChannelDisplay(channel: self, unit: measure.label(units), decimals: 0)
  }

  /// The wire reading at which a sudden zero after it cannot be real, in the wire's
  /// units: the 100-minute cap a no-deco limit shows with nothing to count, and a
  /// surface gradient factor of 5 %, which no tissue off-gases from in one sample.
  var spuriousZeroAfter: Int? {
    switch self {
    case .ndl: 100 * 60
    case .surfaceGradientFactor: 5
    default: nil
    }
  }
}
