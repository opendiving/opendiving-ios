/// One channel's readings, converted to the unit a diver reads them in.
public struct ChannelSeries: Hashable, Sendable {
  public var display: ChannelDisplay
  /// Elapsed milliseconds from the recording's start, as served.
  public var times: [Int]
  public var values: [Double]
  /// The cylinder a pressure series belongs to, by its gas number; nil for every other
  /// channel.
  public var gasNumber: Int?

  public init(display: ChannelDisplay, times: [Int], values: [Double], gasNumber: Int? = nil) {
    self.display = display
    self.times = times
    self.values = values
    self.gasNumber = gasNumber
  }
}
