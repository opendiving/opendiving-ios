/// A channel as one unit system quotes it.
public struct ChannelDisplay: Hashable, Sendable {
  public var channel: ProfileChannel
  public var unit: String
  public var decimals: Int

  public init(channel: ProfileChannel, unit: String, decimals: Int) {
    self.channel = channel
    self.unit = unit
    self.decimals = decimals
  }

  /// A reading already in this display's unit, at its decimals: `21.62°C`, `205 bar`,
  /// `23.4%`. Nothing is converted here — the series was converted when it was built.
  public func format(_ value: Double) -> String {
    NumberText.fixed(value, decimals: decimals) + channel.separator + unit
  }
}
