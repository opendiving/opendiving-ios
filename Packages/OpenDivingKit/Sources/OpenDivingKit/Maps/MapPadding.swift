/// How far in from each edge of a map's frame, in points, a fit keeps what it fits.
public struct MapPadding: Equatable, Sendable {
  public var top: Double
  public var left: Double
  public var bottom: Double
  public var right: Double

  public init(top: Double, left: Double, bottom: Double, right: Double) {
    self.top = top
    self.left = left
    self.bottom = bottom
    self.right = right
  }

  public init(_ all: Double) {
    self.init(top: all, left: all, bottom: all, right: all)
  }
}
