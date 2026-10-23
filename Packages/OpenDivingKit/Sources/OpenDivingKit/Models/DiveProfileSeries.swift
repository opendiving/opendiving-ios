/// One channel of a profile: times in milliseconds from the recording's start, values in the
/// channel's integer scale.
public struct DiveProfileSeries: Codable, Hashable, Sendable {
  public let times: [Int]
  public let values: [Int]
}
