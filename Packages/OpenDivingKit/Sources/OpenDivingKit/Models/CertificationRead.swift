import Foundation

/// A c-card.
public struct CertificationRead: Codable, Hashable, Sendable, Identifiable {
  public var id: UUID { uuid }

  public let uuid: UUID
  /// An agency key, as the API sent it; `other` names it in `agencyOther`.
  public let agency: String
  public let agencyOther: String?
  /// The level as printed.
  public let name: String
  public let certificationNumber: String?
  public let certifiedOn: CalendarDate?
  public let expiresOn: CalendarDate?
  public let instructorNumber: String?
  public let notes: String
  public let userUuid: UUID
  public let courseUuid: UUID?
  /// The dive centre.
  public let contactUuid: UUID?
  /// A person in the people table.
  public let instructorUuid: UUID?
  public let files: [CertificationFileInfo]
  public let createdAt: DiveTimestamp

  /// The stored side named `side`, `front` or `back`; nil when that side has no file.
  public func file(side: String) -> CertificationFileInfo? {
    files.first { $0.side == side }
  }
}
