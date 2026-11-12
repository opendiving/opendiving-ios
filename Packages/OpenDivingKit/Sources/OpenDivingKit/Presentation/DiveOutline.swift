/// A dive card's depth line, as fractions of its box: each depth, a fraction of the deepest, at
/// the middle of its own slice of the width, and the surface pinned at both ends, where every
/// dive starts and finishes. The line is a monotone cubic through those corners, as the web
/// draws it: unlike Catmull-Rom it never overshoots a neighbour, so it never draws a depth the
/// dive did not reach.
public enum DiveOutline {
  public struct Vertex: Hashable, Sendable {
    public let x: Double
    /// Down from the surface.
    public let y: Double
  }

  /// One cubic Bézier piece of the line, from one corner to the next.
  public struct Segment: Hashable, Sendable {
    public let start: Vertex
    public let control1: Vertex
    public let control2: Vertex
    public let end: Vertex
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

  /// The line's pieces, left to right; none for no depths.
  public static func segments(_ depths: [Double]) -> [Segment] {
    let line = vertices(depths)
    let slopes = tangents(line)
    return line.indices.dropLast().map { index in
      let start = line[index]
      let end = line[index + 1]
      let third = (end.x - start.x) / 3
      return Segment(
        start: start,
        control1: Vertex(x: start.x + third, y: start.y + slopes[index] * third),
        control2: Vertex(x: end.x - third, y: end.y - slopes[index + 1] * third),
        end: end)
    }
  }

  /// The shallowest the line comes between `from` and `to`, fractions of the width; nil for no
  /// line.
  public static func shallowest(_ depths: [Double], from: Double, to: Double) -> Double? {
    let pieces = segments(depths)
    guard !pieces.isEmpty else { return nil }
    let from = min(max(from, 0), 1)
    let to = min(max(to, from), 1)
    // Each piece runs monotone between its corners, so the line's shallowest over the span is
    // at one of its ends or at a corner inside it.
    let inside = pieces.map(\.end).filter { $0.x > from && $0.x < to }.map(\.y)
    return ([depth(pieces, at: from), depth(pieces, at: to)] + inside).min()
  }

  /// Fritsch–Carlson: the secants' mean at each corner, flat where the line turns over, and pulled
  /// back where it would let a piece leave the band between its corners.
  private static func tangents(_ line: [Vertex]) -> [Double] {
    guard line.count > 1 else { return line.map { _ in 0 } }
    let secants = line.indices.dropLast().map { index in
      let width = line[index + 1].x - line[index].x
      return width > 0 ? (line[index + 1].y - line[index].y) / width : 0
    }
    var slopes = [Double](repeating: 0, count: line.count)
    slopes[0] = secants[0]
    slopes[line.count - 1] = secants[secants.count - 1]
    for index in 1..<line.count - 1 where secants[index - 1] * secants[index] > 0 {
      slopes[index] = (secants[index - 1] + secants[index]) / 2
    }
    for (index, secant) in secants.enumerated() {
      guard secant != 0 else {
        slopes[index] = 0
        slopes[index + 1] = 0
        continue
      }
      let start = slopes[index] / secant
      let end = slopes[index + 1] / secant
      let distance = start * start + end * end
      if distance > 9 {
        let scale = 3 / distance.squareRoot()
        slopes[index] = scale * start * secant
        slopes[index + 1] = scale * end * secant
      }
    }
    return slopes
  }

  /// The line's depth at `x`. A piece's controls sit at its thirds, so its x runs linearly in t
  /// and t is the fraction of the piece's width.
  private static func depth(_ pieces: [Segment], at x: Double) -> Double {
    guard let piece = pieces.first(where: { $0.end.x >= x }) ?? pieces.last else { return 0 }
    let width = piece.end.x - piece.start.x
    let t = width > 0 ? min(max((x - piece.start.x) / width, 0), 1) : 0
    let u = 1 - t
    return u * u * u * piece.start.y + 3 * u * u * t * piece.control1.y + 3 * u * t * t
      * piece.control2.y + t * t * t * piece.end.y
  }
}
