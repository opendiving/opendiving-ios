import Foundation

/// The tide around an hour as the web's dive page draws it: a half cosine from the turn before the
/// hour to the turn after, run on a quarter of that span past each turn, with the hour marked on
/// it. A half cosine is what an hourly model's tide is between two turns near enough for a shape,
/// and it needs nothing but the two turns' times; past them it is the same curve continued rather
/// than anything the provider answered, so the view draws those stretches fainter.
///
/// Every point is a fraction of the drawing's box, `y` growing downward; the height keeps no scale.
public struct TideCurve: Hashable, Sendable {
  public typealias Point = CurvePoint

  /// A turn's label under the curve, centred on `x`.
  public struct Turn: Hashable, Sendable {
    public let x: Double
    /// `High` or `Low`.
    public let label: String
    /// `18:00`, on the place's own clock.
    public let clock: String
  }

  /// The continuation before the first turn.
  public let before: [Point]
  /// From the first turn to the second: the provider's own span.
  public let between: [Point]
  /// The continuation after the second turn.
  public let after: [Point]
  /// The hour the reading is for; nil where it lies outside the drawing.
  public let now: Point?
  public let turns: [Turn]
  /// The curve in words, for VoiceOver.
  public let accessibilityLabel: String

  static let overrun = 0.25
  static let samples = 64.0

  /// Nil unless both turns are a high or a low at a known instant, the second after the first.
  public init?(
    previous: ConditionsExtreme, next: ConditionsExtreme, now: DiveTimestamp?, state: String?
  ) {
    guard let first = previous.at.instant?.timeIntervalSince1970,
      let second = next.at.instant?.timeIntervalSince1970, second > first,
      let firstLabel = Self.kinds[previous.kind], let secondLabel = Self.kinds[next.kind]
    else { return nil }
    let half = second - first
    let from = first - half * Self.overrun
    let to = second + half * Self.overrun
    let sign = previous.kind == "high" ? 1.0 : -1.0

    func point(_ time: Double) -> Point {
      // 0.1 to 0.9, so a turn is never drawn against the box's edge.
      Point(
        x: (time - from) / (to - from),
        y: 0.5 - sign * cos(Double.pi * (time - first) / half) * 0.4)
    }
    func span(_ start: Double, _ end: Double) -> [Point] {
      let steps = max(2, Int((Self.samples * (end - start) / (to - from)).rounded(.up)))
      return (0...steps).map { point(start + (end - start) * Double($0) / Double(steps)) }
    }

    before = span(from, first)
    between = span(first, second)
    after = span(second, to)
    let hour = now?.instant?.timeIntervalSince1970
    self.now = hour.flatMap { (from...to).contains($0) ? point($0) : nil }
    turns = [
      Turn(x: point(first).x, label: firstLabel, clock: DateText.diveTime(previous.at)),
      Turn(x: point(second).x, label: secondLabel, clock: DateText.diveTime(next.at)),
    ]

    let waters = [previous, next].map { "\($0.kind) water at \(DateText.diveTime($0.at))" }
    var label = "Tide: " + waters.joined(separator: ", ")
    if let now, self.now != nil {
      label += "; now \(DateText.diveTime(now))"
      if let state, let phrase = Self.phrases[state] { label += ", \(phrase)" }
    }
    accessibilityLabel = label
  }

  static let kinds = ["high": "High", "low": "Low"]
  static let phrases = [
    "high": "at high water", "low": "at low water", "rising": "on the rising tide",
    "falling": "on the falling tide",
  ]
}
