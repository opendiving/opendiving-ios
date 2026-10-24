import Foundation

/// A dive draft, `GET /dive-draft/{uuid}` and a row of `GET /dive-drafts`: a dive not yet
/// logged, which either device can finish. `values` holds only the references the account
/// still has — one to a record deleted since comes back without it.
public struct DiveDraftRead: Codable, Hashable, Sendable {
  public let uuid: UUID
  public let createdAt: DiveTimestamp
  public let updatedAt: DiveTimestamp
  public let gearSetUuid: UUID?
  public let values: DiveDraftValues

  /// What writing this draft back unchanged would send.
  public var write: DiveDraftWrite {
    DiveDraftWrite(gearSet: gearSetUuid.map(RecordRef.server), values: values)
  }
}
