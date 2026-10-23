/// One cylinder's share of a multi-cylinder dive's gas use.
public struct DiveTankGasUse: Codable, Hashable, Sendable {
  public let gasNumber: Int
  /// Litres at surface pressure.
  public let gasUsed: Double
  /// Litres per minute at surface pressure.
  public let rmv: Double
  public let sacBarPerMin: Double
  public let secondsOnGas: Int
  /// Metres.
  public let meanDepth: Double
}
