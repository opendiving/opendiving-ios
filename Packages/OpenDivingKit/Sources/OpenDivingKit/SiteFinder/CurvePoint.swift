/// A point of a drawing the Kit lays out for a view, as fractions of the drawing's box, `y`
/// growing downward.
public struct CurvePoint: Hashable, Sendable {
  public let x: Double
  public let y: Double
}
