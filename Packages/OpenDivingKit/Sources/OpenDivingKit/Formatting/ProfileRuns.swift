/// How a channel's samples join into drawable lines: the runs, the threshold the
/// readout is cut at, and every sample a run kept.
public struct ProfileRuns: Hashable, Sendable {
  /// The distance from a sample within which the readout may quote it, in milliseconds.
  public var readoutTolerance: Double
  /// Runs of indices into the series, each drawn as one line.
  public var segments: [[Int]]
  /// Every index some run holds: the samples that are on the chart.
  public var drawn: Set<Int>
}
