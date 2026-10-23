import Foundation

/// A c-card as the cached sheet holds it: the card, the names its uuids resolved to when the
/// sheet was refreshed, and its stored sides — so that every row reads signed out too.
public struct CheckinSheetCard: Codable, Hashable, Sendable, Identifiable {
  public var id: UUID { certification.uuid }

  public let certification: CertificationRead
  /// `GET /course/{uuid}`'s name.
  public let courseName: String?
  /// `GET /contact/{uuid}`'s name.
  public let diveCenterName: String?
  /// The instructor's name in the people table.
  public let instructorName: String?
  public let front: CheckinSheetFile?
  public let back: CheckinSheetFile?

  public init(
    certification: CertificationRead, courseName: String?, diveCenterName: String?,
    instructorName: String?, front: CheckinSheetFile?, back: CheckinSheetFile?
  ) {
    self.certification = certification
    self.courseName = courseName
    self.diveCenterName = diveCenterName
    self.instructorName = instructorName
    self.front = front
    self.back = back
  }
}
