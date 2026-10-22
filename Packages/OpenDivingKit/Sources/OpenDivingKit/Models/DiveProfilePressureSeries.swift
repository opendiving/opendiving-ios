/// One cylinder's pressure, in tenths of a bar.
public struct DiveProfilePressureSeries: Codable, Hashable, Sendable {
  public let times: [Int]
  public let values: [Int]
  /// The device's label for the cylinder, as a mixture's `gasNumber` carries it.
  public let gasNumber: Int
}
