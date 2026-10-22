import Foundation

/// The dive either side of another, enough to label a link to it.
public struct DiveNeighbor: Codable, Hashable, Sendable {
  public let uuid: UUID
  public let diveNumber: Int
  public let startTime: DiveTimestamp
}
