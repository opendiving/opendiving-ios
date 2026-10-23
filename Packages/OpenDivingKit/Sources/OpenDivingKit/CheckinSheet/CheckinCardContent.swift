import Foundation

/// One c-card as the sheet draws it, every value already a string: the web's certification
/// dialog, row for row, with each empty row left out.
public struct CheckinCardContent: Hashable, Sendable, Identifiable {
  /// One face of the card: a stored picture, or the frame saying there is none.
  public struct Side: Hashable, Sendable, Identifiable {
    public var id: String { label }
    /// `Front` or `Back`.
    public let label: String
    /// `No front image`, drawn in a dashed frame where there is no file.
    public let missingText: String
    public let file: CheckinSheetFile?
  }

  public let id: UUID
  public let name: String
  public let agency: String?
  public let expiry: CertificationExpiry?
  /// Certification number, course, certified on, expires on, dive center, instructor and
  /// instructor number, those that have a value.
  public let rows: [Figure]
  public let notes: String?
  /// Front, then back, each whether or not it has a file.
  public let sides: [Side]

  public init(_ card: CheckinSheetCard, today: CalendarDate) {
    let certification = card.certification
    id = certification.uuid
    name = certification.name
    agency = VocabularyLabels.certificationAgency(
      certification.agency, other: certification.agencyOther)
    expiry = CertificationExpiry(expiresOn: certification.expiresOn, today: today)
    rows = [
      Figure.row("Certification number", certification.certificationNumber),
      Figure.row("Course", card.courseName),
      Figure.row("Certified on", certification.certifiedOn.map(DateText.date)),
      Figure.row("Expires on", certification.expiresOn.map(DateText.date)),
      Figure.row("Dive center", card.diveCenterName),
      Figure.row("Instructor", card.instructorName),
      Figure.row("Instructor number", certification.instructorNumber),
    ].compactMap { $0 }
    notes = certification.notes.isEmpty ? nil : certification.notes
    sides = [("front", card.front), ("back", card.back)].map { side, file in
      Side(
        label: VocabularyLabels.certificationSide(side) ?? side,
        missingText: "No \(side) image", file: file)
    }
  }
}

extension Figure {
  /// A row with a value, or nil to leave it out, as the web renders nothing for an empty
  /// detail.
  static func row(_ label: String, _ value: String?) -> Figure? {
    guard let value, !value.isEmpty else { return nil }
    return Figure(label: label, value: value)
  }
}
