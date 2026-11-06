/// A held pin, in the map's points: it rides above the finger so the finger does not hide it, and
/// drops where it is drawn. A hold released without a drag is no move at all, so nothing is
/// dropped and the pin goes back.
public struct PinDrag: Hashable, Sendable {
  public struct Point: Hashable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
      self.x = x
      self.y = y
    }

    func distance(to other: Point) -> Double {
      ((x - other.x) * (x - other.x) + (y - other.y) * (y - other.y)).squareRoot()
    }
  }

  /// How far above the finger the pin rides.
  static let lift = 56.0
  /// How far a finger strays in a still hold.
  static let dragDistance = 8.0
  /// A fingertip's reach around the pin, which is much smaller than it.
  static let reach = 28.0

  private let pin: Point
  private let start: Point
  private var finger: Point
  private var hasDragged = false

  public init(pin: Point, finger: Point) {
    self.pin = pin
    start = finger
    self.finger = finger
  }

  /// Whether a touch here is on the pin.
  public static func isOnPin(_ pin: Point, touch: Point) -> Bool {
    pin.distance(to: touch) <= reach
  }

  /// Latched: a finger that strays and comes back has still dragged.
  public mutating func moved(to finger: Point) {
    self.finger = finger
    if finger.distance(to: start) > Self.dragDistance { hasDragged = true }
  }

  /// Where the pin is drawn while it is held.
  public var held: Point { Point(x: finger.x, y: finger.y - Self.lift) }

  /// `held` from the pin's own place.
  public var offset: Point { Point(x: held.x - pin.x, y: held.y - pin.y) }

  /// Where it lands on release, or nil when it goes back.
  public var drop: Point? { hasDragged ? held : nil }
}
