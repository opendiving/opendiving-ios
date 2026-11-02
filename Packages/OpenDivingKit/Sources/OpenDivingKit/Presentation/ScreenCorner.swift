import Foundation

/// A corner of the screen a floating control rests in.
public enum ScreenCorner: CaseIterable, Hashable, Sendable {
  case topLeading, topTrailing, bottomLeading, bottomTrailing

  /// The corner whose resting place is nearest `point`, where `place` gives each corner's.
  public static func nearest(to point: CGPoint, place: (ScreenCorner) -> CGPoint) -> ScreenCorner {
    allCases.min { a, b in
      distance(point, place(a)) < distance(point, place(b))
    } ?? .bottomLeading
  }

  private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    hypot(a.x - b.x, a.y - b.y)
  }
}
