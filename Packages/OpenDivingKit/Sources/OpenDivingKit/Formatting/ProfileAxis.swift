/// A scale the profile chart draws curves against, named after the quantity rather than
/// the unit: ppO₂ and tank pressure are both bar and never one axis, and a 99-minute
/// no-deco limit and a few minutes to surface are both minutes and never one either.
public enum ProfileAxis: String, Sendable, Hashable, CaseIterable {
  case depth
  case temperature
  case pressure
  case noDeco = "no_deco"
  case timeToSurface = "time_to_surface"
  case ppo2
  case percent

  /// The rows of the deco panel under the depth plot, in the order they stack. The depth
  /// plot has two edges and holds three scales at most; these four are given a row each
  /// so every curve is drawn against numbers that belong to it.
  public static let panels: [ProfileAxis] = [.noDeco, .timeToSurface, .ppo2, .percent]

  /// The value this axis will not scale past, however high a reading goes. Only percent
  /// has one: a Suunto Ocean's `gf99` reads 14 060 % on a deep decompression ascent — a
  /// fault — and fitted to it the row would draw the surface gradient factor beside it as
  /// a flat line. 200 % is twice the M-value, past anything a diver can act on.
  public var bound: Double? {
    self == .percent ? 200 : nil
  }

  /// The domain this axis draws `values` against: ``AxisDomain/nice(_:targetTicks:)``,
  /// or the band up to ``bound`` where the readings overrun it. The readings are never
  /// altered — a curve that overruns is drawn leaving the row.
  public func domain(_ values: [Double]) -> AxisDomain {
    let fitted = AxisDomain.nice(values)
    guard let bound, fitted.max > bound else { return fitted }
    return AxisDomain.nice([0, bound])
  }

  /// What follows the number on a panel row's top tick — separator and unit both, so
  /// `40 min` and `100%` are each spaced as the quantity is written.
  public func unitSuffix(_ units: UnitSystem) -> String {
    guard let channel = ProfileChannel.allCases.first(where: { $0.axis == self }) else {
      return ""
    }
    return channel.separator + channel.display(units).unit
  }

  /// The channels on this axis, in the legend's order.
  public var channels: [ProfileChannel] {
    ProfileChannel.allCases.filter { $0.axis == self }
  }

  /// The temperature axis: ``AxisDomain/nice(_:targetTicks:)`` over the readings, widened
  /// about their middle to at least 2 °C in the diver's units, so a dive whose water moved
  /// 0.4 °C is not drawn as a staircase across the whole plot.
  public static func temperatureDomain(_ values: [Double], units: UnitSystem) -> AxisDomain {
    guard let lowest = values.min(), let highest = values.max() else {
      return AxisDomain.nice([])
    }
    let span =
      Measure.temperature.toDisplay(minimumTemperatureSpan, units)
      - Measure.temperature.toDisplay(0, units)
    let middle = (lowest + highest) / 2
    return AxisDomain.nice(values + [middle - span / 2, middle + span / 2])
  }

  /// The one axis depth and the ceiling share, anchored at the surface. A ceiling is a
  /// bound on the depth curve, so on an axis of its own a 3 m ceiling could be drawn
  /// below a 40 m depth.
  public static func depthDomain(depth: [Double], ceiling: [Double]) -> AxisDomain {
    AxisDomain.nice([0] + depth + ceiling)
  }

  /// In degrees Celsius.
  static let minimumTemperatureSpan = 2.0
}

extension ProfileChannel {
  /// The axis this channel is scaled against.
  public var axis: ProfileAxis {
    switch self {
    case .depth, .ceiling: .depth
    case .temperature: .temperature
    case .pressure: .pressure
    case .ndl: .noDeco
    case .tts: .timeToSurface
    case .ppo2: .ppo2
    case .cns, .surfaceGradientFactor, .gradientFactor: .percent
    }
  }
}

/// Where a selection's scales go: which channel labels the depth plot's left edge, which
/// its right, which is numbered under the right one's, and which rows the deco panel grows.
/// The sides are fixed while there are two scales to tell apart — metres left, temperature
/// right, pressure on whichever the others leave free — so an axis does not change edges
/// with the channel mix from one dive to the next.
public struct ProfileScalePlacement: Hashable, Sendable {
  /// Labels the depth plot's left edge; nil only when nothing is plotted on it.
  public var left: ProfileChannel?
  /// Labels its right edge, exactly when the plot holds a second scale.
  public var right: ProfileChannel?
  /// Numbered under ``right``'s labels at the same heights, when the plot holds a third
  /// scale: pressure under temperature.
  public var underRight: ProfileChannel?
  /// One row per axis the selection puts below the depth plot, in
  /// ``ProfileAxis/panels`` order.
  public var panels: [ProfileAxis]

  public init(shown: Set<ProfileChannel>) {
    let vertical: ProfileChannel? =
      shown.contains(.depth) ? .depth : shown.contains(.ceiling) ? .ceiling : nil
    let temperature: ProfileChannel? = shown.contains(.temperature) ? .temperature : nil
    let pressure: ProfileChannel? = shown.contains(.pressure) ? .pressure : nil
    let scales = [vertical, temperature, pressure].compactMap { $0 }
    let hasTwoScales = scales.count > 1

    left = hasTwoScales ? (vertical ?? pressure) : scales.first
    right = hasTwoScales ? (temperature ?? pressure) : nil
    underRight = scales.count == 3 ? pressure : nil
    panels = ProfileAxis.panels.filter { axis in shown.contains { $0.axis == axis } }
  }
}
