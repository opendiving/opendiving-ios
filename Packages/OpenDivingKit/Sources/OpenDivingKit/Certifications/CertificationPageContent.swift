import Foundation

/// A certification's page, the web's view dialog row for row: its level with the agency and
/// expiry badges, both sides, the details that have a value, and its notes. A course, a dive
/// centre or an instructor the phone holds only as a uuid is left out until it holds the name.
public struct CertificationPageContent: Hashable, Sendable {
  /// One face of the card.
  public struct Side: Hashable, Sendable, Identifiable {
    public var id: CertificationSide { side }
    public let side: CertificationSide
    /// `Front` or `Back`.
    public let title: String
    public let file: CertificationFileInfo?

    public var isPDF: Bool { file?.contentType == CertificationCardEdits.pdfContentType }
  }

  /// One detail, and the page it opens where it names a record that has one.
  public struct Row: Hashable, Sendable {
    public enum Link: Hashable, Sendable {
      case course(UUID)
      case person(UUID)
    }

    public let label: String
    public let value: String
    public let link: Link?
  }

  public let name: String
  public let agency: String?
  public let expiry: CertificationExpiry?
  public let sides: [Side]
  public let rows: [Row]
  public let notes: String?

  public init(
    _ certification: CertificationRead, today: CalendarDate, courseName: String?,
    contactName: String?, instructorName: String?
  ) {
    name = certification.name
    agency = VocabularyLabels.certificationAgency(
      certification.agency, other: certification.agencyOther)
    expiry = CertificationExpiry(expiresOn: certification.expiresOn, today: today)
    sides = CertificationSide.allCases.map { side in
      Side(
        side: side, title: VocabularyLabels.certificationSide(side.rawValue) ?? side.rawValue,
        file: certification.file(side: side.rawValue))
    }
    func row(_ label: String, _ value: String?, _ link: Row.Link? = nil) -> Row? {
      guard let value, !value.isEmpty else { return nil }
      return Row(label: label, value: value, link: link)
    }
    rows = [
      row("Certification number", certification.certificationNumber),
      row("Course", courseName, certification.courseUuid.map(Row.Link.course)),
      row("Certified on", certification.certifiedOn.map(DateText.date)),
      row("Expires on", certification.expiresOn.map(DateText.date)),
      row("Dive center", contactName),
      row("Instructor", instructorName, certification.instructorUuid.map(Row.Link.person)),
      row("Instructor number", certification.instructorNumber),
    ].compactMap { $0 }
    notes = certification.notes.isEmpty ? nil : certification.notes
  }

  /// The page as the phone can name its records: the course from the pickers' rows or the copy
  /// its page keeps, the dive centre from the pickers' rows, the instructor from the people.
  @MainActor
  public init(
    _ certification: CertificationRead, today: CalendarDate, session: Session,
    lookups: LookupsModel
  ) {
    self.init(
      certification, today: today,
      courseName: Self.courseName(certification.courseUuid, session: session, lookups: lookups),
      contactName: RecordNames.contact(certification.contactUuid, lookups: lookups.contacts),
      instructorName: RecordNames.person(
        certification.instructorUuid, people: session.people, lookups: lookups.people))
  }

  @MainActor
  static func courseName(_ uuid: UUID?, session: Session, lookups: LookupsModel) -> String? {
    guard let uuid else { return nil }
    let name =
      lookups.courses.first { $0.ref.serverUUID == uuid }?.name
      ?? AccountStores.current(session)?.cache.record(.course, uuid)?.value.name
    guard let name = name?.trimmedOfWhitespace, !name.isEmpty else { return nil }
    return name
  }

  /// What a failed download says (the web's toast).
  public static let downloadFailed = "Failed to download the file. Please try again."
}
