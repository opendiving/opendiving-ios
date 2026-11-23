import Foundation

/// One row of `POST /dive-computers/known-dives`'s answer: a listed dive the logbook already
/// holds, by the uuid it was sent with, and the logbook's dive that holds it.
public struct KnownDive: Codable, Hashable, Sendable {
  public let uuid: UUID
  public let diveUuid: UUID

  public init(uuid: UUID, diveUuid: UUID) {
    self.uuid = uuid
    self.diveUuid = diveUuid
  }
}
