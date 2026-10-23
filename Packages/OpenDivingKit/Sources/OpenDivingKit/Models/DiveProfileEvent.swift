/// A marker on a profile.
public struct DiveProfileEvent: Codable, Hashable, Sendable {
  /// Milliseconds from the recording's start.
  public let time: Int
  /// The event's name as the API sent it; null is an event the device recorded and the
  /// vocabulary has no word for, with the device's own wording in `label`.
  public let type: String?
  public let gasNumber: Int?
  public let label: String?
}
