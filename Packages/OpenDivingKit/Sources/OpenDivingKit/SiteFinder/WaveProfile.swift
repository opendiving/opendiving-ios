import Foundation

/// The waves and the swell at an hour, drawn as the sea's surface passing a fixed point: a strip
/// each, on one height scale so the two compare at a glance, and a calm sea draws flat.
///
/// Every point is a fraction of its strip's box, `y` growing downward.
public struct WaveProfile: Hashable, Sendable {
  public struct Strip: Hashable, Sendable {
    /// `Waves` or `Swell`.
    public let label: String
    /// `0.9 m · 4 s`, `0.1 m`.
    public let value: String
    public let points: [CurvePoint]
  }

  public let strips: [Strip]
  /// The strips in words, for VoiceOver.
  public let accessibilityLabel: String

  /// The seconds a strip shows of the surface passing.
  static let span = 20.0
  /// The height a strip spans from crest to trough, raised to the highest of the two.
  static let minimumScale = 1.0
  /// The model gives the swell no period of its own, so its strip keeps one fixed rhythm, long as
  /// a swell's is: only its height is to scale.
  static let swellPeriod = 12.0
  static let samples = 96

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
        Strip(
          label: "Waves", value: period.map { "\(shown) · \($0) s" } ?? shown,
          points: Self.surface(height: height, period: sea.wavePeriod, scale: scale)))
      spoken.append(
        "waves " + Self.spoken(height, units) + (period.map { " every \($0) seconds" } ?? ""))
    }
    if let height = sea.swellWaveHeight {
      strips.append(
        Strip(
          label: "Swell", value: UnitFormat.depth(height, units, decimals: 1),
          points: Self.surface(height: height, period: Self.swellPeriod, scale: scale)))
      spoken.append("swell " + Self.spoken(height, units))
    }
    self.strips = strips
    let sentence = spoken.joined(separator: ", ")
    accessibilityLabel = sentence.prefix(1).uppercased() + sentence.dropFirst()
  }

  /// A sine passing for ``span`` seconds, crest to trough `height` against a strip of `scale`; a
  /// wave with no period passes at the swell's.
  static func surface(height: Double, period: Double?, scale: Double) -> [CurvePoint] {
    let period = period.flatMap { $0 > 0 ? $0 : nil } ?? swellPeriod
    // 0.1 to 0.9 at full scale, so a crest is never drawn against the box's edge.
    let amplitude = height / scale * 0.4
    return (0...samples).map { step in
      let x = Double(step) / Double(samples)
      return CurvePoint(x: x, y: 0.5 - amplitude * sin(2 * Double.pi * x * span / period))
    }
  }

  private static func spoken(_ meters: Double, _ units: UnitSystem) -> String {
    UnitFormat.number(meters, .depth, units, decimals: 1) + " " + Measure.depth.word(units)
  }
}
