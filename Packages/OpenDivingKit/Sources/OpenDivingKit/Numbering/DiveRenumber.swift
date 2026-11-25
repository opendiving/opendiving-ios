import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// `POST /dives/renumber`'s body: number the dives in scope consecutively, in date order.
public struct DiveRenumberRequest: Codable, Hashable, Sendable {
  /// The number the earliest dive in scope takes.
  public let startAt: Int
  /// Only dives at or after this instant, which must carry its offset; nil reaches every dive.
  public let fromStartTime: DiveTimestamp?
  /// Work out the changes and write nothing: what the sheet shows before the diver confirms.
  public let dryRun: Bool

  public init(startAt: Int, fromStartTime: DiveTimestamp?, dryRun: Bool) {
    self.startAt = startAt
    self.fromStartTime = fromStartTime
    self.dryRun = dryRun
  }
}

/// One dive whose number the renumber moves.
public struct DiveRenumberChange: Codable, Hashable, Sendable, Identifiable {
  public let diveUuid: UUID
  public let startTime: DiveTimestamp
  public let diveNumber: Int
  public let newDiveNumber: Int

  public var id: UUID { diveUuid }
}

/// What a renumber changes, or changed.
public struct DiveRenumberResult: Codable, Hashable, Sendable {
  public let dryRun: Bool
  public let divesInScope: Int
  /// Every dive whose number moves, in date order; empty for a log already numbered so.
  public let changes: [DiveRenumberChange]
}

extension APIClient {
  /// `POST /dives/renumber`.
  public func renumberDives(_ request: DiveRenumberRequest) async throws -> DiveRenumberResult {
    try await authorizedDecoded(
      DiveRenumberResult.self,
      Call(method: "POST", path: "dives/renumber", body: Self.json(request)))
  }
}
