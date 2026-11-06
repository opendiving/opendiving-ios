/// The stretch of a profile's time axis on screen, in milliseconds. A chart that has not been
/// zoomed shows the whole dive; a pinch narrows the window and moves it with the fingers.
public struct ProfileTimeWindow: Hashable, Sendable {
  public private(set) var start: Int
  public private(set) var end: Int

  /// The shortest stretch of a dive the chart zooms in to.
  static let minimumSpan = 60_000

  /// How near the whole axis a span counts as the whole axis, as a fraction of it, so a
  /// pinch in and back out does not end a few rounding errors short and read as zoomed.
  private static let wholeAxisTolerance = 0.001

  /// The whole of an axis `duration` milliseconds long.
  public init(duration: Int) {
    start = 0
    end = duration
  }

  private init(start: Double, span: Double, duration: Int) {
    let span = min(duration, Int(span.rounded()))
    self.start = min(max(0, Int(start.rounded())), duration - span)
    end = self.start + span
  }

  public var span: Int { end - start }

  /// Whether the window shows less than the whole of an axis `duration` long.
  public func isZoomed(duration: Int) -> Bool {
    span < duration
  }

  /// This window magnified by `factor`, below 1 zooming out, keeping the instant `from` of
  /// the way across it at `to` of the way across the result: fingers that slide pass their
  /// two midpoints, so the dive stays under them, and a `factor` of 1 only moves the window.
  /// The span stays between ``minimumSpan`` and the whole axis, and the window on the axis.
  public func scaled(by factor: Double, from: Double, to: Double, duration: Int)
    -> ProfileTimeWindow
  {
    guard factor > 0, factor.isFinite else { return self }
    let anchor = Double(start) + from * Double(span)
    let fitted = max(Double(min(Self.minimumSpan, duration)), Double(span) / factor)
    let next =
      fitted >= Double(duration) * (1 - Self.wholeAxisTolerance) ? Double(duration) : fitted
    return ProfileTimeWindow(start: anchor - to * next, span: next, duration: duration)
  }
}
