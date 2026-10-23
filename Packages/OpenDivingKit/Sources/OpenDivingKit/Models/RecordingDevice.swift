/// The computer that made a recording, as its own export named it.
public struct RecordingDevice: Codable, Hashable, Sendable {
  public let brand: String?
  public let model: String?
  public let serial: String?
  public let firmware: String?
  public let name: String?
  /// The device's own dive counter, not the diver's numbering.
  public let diveNumber: Int?
}
