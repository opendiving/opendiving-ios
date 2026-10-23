import Foundation

/// A rounded axis span and the step its gridlines take — the web's `Domain`, with its
/// `niceDomain`, `alignedDomain`, `stepCount` and `axisTicks`, ported to agree with it to
/// the last bit so a scale here reads the numbers the web's does.
public struct AxisDomain: Hashable, Sendable {
  public var min: Double
  public var max: Double
  public var step: Double

  public init(min: Double, max: Double, step: Double) {
    self.min = min
    self.max = max
    self.step = step
  }

  /// A rounded domain covering `values`, in about `targetTicks` steps of 1, 2, 2.5 or 5
  /// times a power of ten. Not anchored at zero: depth is, by being handed the surface's
  /// own `0`. A flat series gets a unit either side, and none at all `0...1`.
  public static func nice(_ values: [Double], targetTicks: Int = 5) -> AxisDomain {
    guard let lowest = values.min(), let highest = values.max() else {
      return AxisDomain(min: 0, max: 1, step: 1)
    }
    if highest == lowest {
      return AxisDomain(min: lowest - 1, max: lowest + 1, step: 1)
    }

    let rawStep = (highest - lowest) / Double(targetTicks)
    let magnitude = pow(10, log10(rawStep).rounded(.down))
    let normalized = rawStep / magnitude
    let niceStep = [1, 2, 2.5, 5, 10].first(where: { normalized <= $0 }) ?? 10
    let step = niceStep * magnitude
    return AxisDomain(
      min: (lowest / step).rounded(.down) * step,
      max: (highest / step).rounded(.up) * step,
      step: step)
  }

  /// A rounded domain covering `values` in exactly `steps` gaps, so its gridlines land at
  /// the heights of another axis's with that many: the ladder ``nice(_:targetTicks:)``
  /// climbs, walked up until one rung spans the values from a floor of its own.
  public static func aligned(_ values: [Double], steps: Int) -> AxisDomain {
    guard steps >= 1, let lowest = values.min(), let highest = values.max() else {
      return nice(values)
    }
    let range = highest - lowest
    if range == 0 {
      let min = lowest.rounded(.down) - Double(steps / 2)
      return AxisDomain(min: min, max: min + Double(steps), step: 1)
    }

    var magnitude = pow(10, log10(range / Double(steps)).rounded(.down))
    for _ in 0..<12 {
      for candidate in [1, 2, 2.5, 5] {
        let step = candidate * magnitude
        let min = (lowest / step).rounded(.down) * step
        if min + Double(steps) * step >= highest {
          return AxisDomain(min: min, max: min + Double(steps) * step, step: step)
        }
      }
      magnitude *= 10
    }
    return AxisDomain(min: lowest, max: lowest + range, step: range / Double(steps))
  }

  /// How many gaps the gridlines divide the domain into.
  public var stepCount: Int {
    Int(NumberText.round((max - min) / step))
  }

  /// The gridline values, both ends included, each counted from `min` and settled at ten
  /// decimals rather than accumulated, which drifts to `12.499999999999998`.
  public var ticks: [Double] {
    (0...stepCount).map { index in
      let tick = min + Double(index) * step
      return Double(NumberText.fixed(tick, decimals: 10)) ?? tick
    }
  }

  /// Where `value` sits along the domain, from 0 at `min` to 1 at `max`.
  public func fraction(_ value: Double) -> Double {
    (value - min) / (max - min)
  }

  /// How many labels fit along `length` when each needs `spacing` of it, never fewer
  /// than one.
  public static func labelCapacity(_ length: Double, spacing: Double) -> Int {
    Swift.max(1, Int((length / spacing).rounded(.down)))
  }
}
