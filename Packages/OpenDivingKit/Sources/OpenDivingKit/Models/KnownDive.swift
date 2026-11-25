import Foundation

/// One row of `POST /dive-computers/known-dives`'s answer: a listed dive the logbook already
/// holds, by the uuid it was sent with, the logbook's dive that holds it, and whether that dive
/// keeps the computer's original download of it.
public struct KnownDive: Codable, Hashable, Sendable {
  public let uuid: UUID
  public let diveUuid: UUID
  /// False where the holding dive lacks the computer's original, which a download then takes to
  /// it; nil from a server that does not say, which a download reads as having it.
  public let hasOriginal: Bool?

  public init(uuid: UUID, diveUuid: UUID, hasOriginal: Bool? = nil) {
    self.uuid = uuid
    self.diveUuid = diveUuid
    self.hasOriginal = hasOriginal
  }
}
