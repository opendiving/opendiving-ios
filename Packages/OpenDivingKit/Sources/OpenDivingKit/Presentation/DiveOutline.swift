/// A dive card's depth line, as fractions of its box: each depth, a fraction of the deepest, at
/// the middle of its own slice of the width, and the surface pinned at both ends, where every
/// dive starts and finishes.
public enum DiveOutline {
  public struct Vertex: Hashable, Sendable {
    public let x: Double
    /// Down from the surface.
    public let y: Double
  }

  /// The line's corners, left to right; none for no depths.
  public static func vertices(_ depths: [Double]) -> [Vertex] {
    guard !depths.isEmpty else { return [] }
    let count = Double(depths.count)
    let inner = depths.enumerated().map { index, depth in
      Vertex(x: (Double(index) + 0.5) / count, y: min(max(depth, 0), 1))
    }
    return [Vertex(x: 0, y: 0)] + inner + [Vertex(x: 1, y: 0)]
  }

  /// The shallowest the line comes between `from` and `to`, fractions of the width; nil for no
  /// line.
  public static func shallowest(_ depths: [Double], from: Double, to: Double) -> Double? {
    let line = vertices(depths)
    guard !line.isEmpty else { return nil }
    let from = min(max(from, 0), 1)
    let to = min(max(to, from), 1)
    let inside = line.filter { $0.x > from && $0.x < to }.map(\.y)
    return ([depth(line, at: from), depth(line, at: to)] + inside).min()
  }

  private static func depth(_ line: [Vertex], at x: Double) -> Double {
    guard let right = line.firstIndex(where: { $0.x >= x }), right > 0 else { return line[0].y }
    let a = line[right - 1]
    let b = line[right]
    return a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x)
  }
}
