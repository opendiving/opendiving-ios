/// A percentage as two wheels hold it, a whole number and tenths: what a gas analyser reads.
/// Nil on the whole wheel is *Not recorded*.
public struct PercentWheels: Equatable, Sendable {
  public var whole: Int? {
    didSet {
      if !takesTenths { tenth = 0 }
    }
  }
  public var tenth: Int

  public static let wholes = 0...100
  public static let tenths = 0...9

  public init(_ percent: Double?) {
    guard let percent else {
      whole = nil
      tenth = 0
      return
    }
    let tenths = Int((min(max(percent, 0), 100) * 10).rounded())
    whole = tenths / 10
    tenth = tenths % 10
  }

  /// The percentage on the wheels, which stop at 100.
  public var percent: Double? {
    whole.map { min(Double($0 * 10 + tenth) / 10, 100) }
  }

  /// Whether the tenths wheel has anything to add.
  public var takesTenths: Bool { whole != nil && whole != Self.wholes.upperBound }
}
