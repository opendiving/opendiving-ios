/// The API's gas-consumption figures for a dive, shown as they arrive.
public struct DiveGasUse: Codable, Hashable, Sendable {
  /// Litres at surface pressure.
  public let gasUsed: Double
  /// Litres per minute at surface pressure.
  public let rmv: Double
  /// Null on a multi-cylinder dive, where each tank carries its own.
  public let sacBarPerMin: Double?
  public let tanks: [DiveTankGasUse]
  public let attributedSeconds: Int?
  /// What `attributedSeconds` is a fraction of, in seconds.
  public let duration: Int?
}
