/// `GET /dives/next-number`: the number a dive starting then would take — the preceding dive's
/// plus one — and whether a dive already carries it, which is advisory.
public struct DiveNumberSuggestion: Codable, Hashable, Sendable {
  public let diveNumber: Int
  public let isTaken: Bool
}
