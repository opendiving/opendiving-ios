/// The decompression model a computer ran, and how it was set.
public struct RecordingDecoModel: Codable, Hashable, Sendable {
  /// The model's family, as the API sent it.
  public let algorithm: String?
  /// The device's own name for its model; free text.
  public let name: String?
  public let gfLow: Int?
  public let gfHigh: Int?
  /// On the device's own scale; negative values are real.
  public let conservatism: Int?
}
