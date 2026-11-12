import Foundation

/// The waves and the swell at an hour, drawn as the sea's surface passing a fixed point: a strip
/// each, on one height scale so the two compare at a glance, and a calm sea draws flat.
///
/// The surface is a trochoid, the shape a wave's water takes: sharp crests over long flat troughs,
/// each crest leaning toward where the wave travels. The swell is smoothed and upright, as swell
/// is. Behind each surface runs a fainter row, lower, slower and a third of a wave along, for
/// depth; it is drawing, not data, and only the front row's height and period are to scale.
///
/// Every point is a fraction of its strip's box, `y` growing downward.
public struct WaveProfile: Hashable, Sendable {
  public struct Strip: Hashable, Sendable {
    /// `Waves` or `Swell`.
    public let label: String
    /// `0.9 m · 4 s`, `0.1 m`.
    public let value: String
    /// The surface itself, its line drawn.
    public let surface: [CurvePoint]
    /// The fainter row behind it, filled only.
    public let behind: [CurvePoint]
  }

  public let strips: [Strip]
  /// The strips in words, for VoiceOver.
  public let accessibilityLabel: String

  /// The seconds a strip shows of the surface passing.
  static let span = 14.0
  /// The height a strip spans from crest to trough, raised to the highest of the two.
  static let minimumScale = 1.0
  /// The model gives the swell no period of its own, so its strip keeps one fixed rhythm, long as
  /// a swell's is: only its height is to scale.
  static let swellPeriod = 12.0

  /// How far each crest sharpens: 0 is a sine, 1 a cusp.
  static let waveSteepness = 0.5
  static let swellSteepness = 0.175
  /// How far, in radians of a wave, each crest leans ahead of its trough.
  static let waveLean = 1.0

  static let behindHeight = 0.55
  static let behindPeriod = 1.15
  static let behindLean = 0.5
  static let behindLift = 0.03
  static let behindPhase = 2 * Double.pi / 3

  /// Nil where the sea gives neither a wave height nor a swell height.
  public init?(_ sea: ConditionsSea, units: UnitSystem) {
    let heights = [sea.waveHeight, sea.swellWaveHeight].compactMap { $0 }
    guard let highest = heights.max() else { return nil }
    let scale = max(Self.minimumScale, highest)

    var strips: [Strip] = []
    var spoken: [String] = []
    if let height = sea.waveHeight {
      let period = sea.wavePeriod.map { NumberText.fixed(NumberText.round($0), decimals: 0) }
      let shown = UnitFormat.depth(height, units, decimals: 1)
      strips.append(
        Self.strip(
          "Waves", value: period.map { "\(shown) · \($0) s" } ?? shown, height: height,
          period: sea.wavePeriod, scale: scale, steepness: Self.waveSteepness, lean: Self.waveLean))
      spoken.append(
        "waves " + Self.spoken(height, units) + (period.map { " every \($0) seconds" } ?? ""))
    }
    if let height = sea.swellWaveHeight {
      strips.append(
        Self.strip(
          "Swell", value: UnitFormat.depth(height, units, decimals: 1), height: height,
          period: Self.swellPeriod, scale: scale, steepness: Self.swellSteepness, lean: 0))
      spoken.append("swell " + Self.spoken(height, units))
    }
    self.strips = strips
    let sentence = spoken.joined(separator: ", ")
    accessibilityLabel = sentence.prefix(1).uppercased() + sentence.dropFirst()
  }

  private static func strip(
    _ label: String, value: String, height: Double, period: Double?, scale: Double,
    steepness: Double, lean: Double
  ) -> Strip {
    // A wave with no period passes at the swell's.
    let period = period.flatMap { $0 > 0 ? $0 : nil } ?? swellPeriod
    return Strip(
      label: label, value: value,
      surface: surface(
        height: height, period: period, scale: scale, steepness: steepness, lean: lean),
      behind: surface(
        height: height * behindHeight, period: period * behindPeriod, scale: scale,
        steepness: steepness, lean: lean * behindLean, phase: behindPhase
      ).map { CurvePoint(x: $0.x, y: $0.y - behindLift) })
  }

  /// A trochoid passing for ``span`` seconds, crest to trough `height` against a strip of `scale`,
  /// its crests `phase` radians along.
  static func surface(
    height: Double, period: Double, scale: Double, steepness: Double, lean: Double,
    phase: Double = 0
  ) -> [CurvePoint] {
    // 0.1 to 0.9 at full scale, so a crest is never drawn against the box's edge.
    let amplitude = height / scale * 0.4
    let cycles = span / period
    // From a wave and a half before the strip to one and a half past it, so that wherever the
    // lean and the phase move the crests, the line reaches both edges.
    let first = -3 * Double.pi
    let last = 2 * Double.pi * (cycles + 1.5)
    let samples = Int((cycles + 3) * 120)
    let points = (0...samples).map { step in
      let theta = first + (last - first) * Double(step) / Double(samples)
      let crest = pow((cos(theta) + 1) / 2, 3)
      let along = theta - steepness * sin(theta) + lean * crest + phase
      return CurvePoint(
        x: along / (2 * Double.pi) * period / span, y: 0.5 - amplitude * cos(theta))
    }
    // A leaning crest runs backward, so the line can cross an edge more than once; cut it where
    // it last enters the strip and first leaves it, so each edge holds one point rather than a
    // run of them drawn as a tick.
    guard let start = points.lastIndex(where: { $0.x < 0 }),
      let end = points[start...].firstIndex(where: { $0.x > 1 })
    else { return points }
    return [edge(points[start], points[start + 1], at: 0)] + points[(start + 1)..<end]
      + [edge(points[end - 1], points[end], at: 1)]
  }

  /// Where the segment from `a` to `b` crosses `x`.
  private static func edge(_ a: CurvePoint, _ b: CurvePoint, at x: Double) -> CurvePoint {
    CurvePoint(x: x, y: a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x))
  }

  private static func spoken(_ meters: Double, _ units: UnitSystem) -> String {
    UnitFormat.number(meters, .depth, units, decimals: 1) + " " + Measure.depth.word(units)
  }
}
