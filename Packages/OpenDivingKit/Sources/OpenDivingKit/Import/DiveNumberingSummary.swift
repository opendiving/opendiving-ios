import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// `GET /dives/numbering`: the state of the account's dive numbering.
public struct DiveNumberingSummary: Codable, Hashable, Sendable {
  public let totalDives: Int
  /// Null only when the log is empty.
  public let lowest: Int?
  public let highest: Int?
  /// How many numbers between `lowest` and `highest` no dive uses.
  public let missingCount: Int
  /// How many dives carry a number another dive also carries.
  public let duplicateCount: Int
  /// How many dives are numbered lower than the dive before them in date order.
  public let outOfDateOrderCount: Int
  public let isSequential: Bool

  public init(
    totalDives: Int, lowest: Int?, highest: Int?, missingCount: Int, duplicateCount: Int,
    outOfDateOrderCount: Int, isSequential: Bool
  ) {
    self.totalDives = totalDives
    self.lowest = lowest
    self.highest = highest
    self.missingCount = missingCount
    self.duplicateCount = duplicateCount
    self.outOfDateOrderCount = outOfDateOrderCount
    self.isSequential = isSequential
  }
}

extension APIClient {
  /// `GET /dives/numbering`.
  public func diveNumbering() async throws -> DiveNumberingSummary {
    try await authorizedDecoded(DiveNumberingSummary.self, Call(method: "GET", path: "dives/numbering"))
  }
}
