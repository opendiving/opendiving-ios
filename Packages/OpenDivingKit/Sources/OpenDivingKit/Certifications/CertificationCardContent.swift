import Foundation

/// One certification as a card on More's *Certifications* (`CertificationCard`): its level over
/// the foot of its front, the expiry badge, the agency under, and the number a dive shop asks for
/// and when it was earned as its figures.
public struct CertificationCardContent: Hashable, Sendable, Identifiable {
  public let id: UUID
  public let name: String
  public let expiry: CertificationExpiry?
  public let agency: String?
  /// Number and Certified, those that have a value.
  public let figures: [Figure]
  /// The front, drawn behind the details; nil with none stored or a PDF, which is never drawn.
  public let front: CertificationFileInfo?
  /// The icon in the water where no front is drawn: none stored, a PDF, or one that could not
  /// be had.
  public let missingFrontIcon: Icon

  public init(_ certification: CertificationRead, today: CalendarDate) {
    id = certification.uuid
    name = certification.name
    expiry = CertificationExpiry(expiresOn: certification.expiresOn, today: today)
    agency = VocabularyLabels.certificationAgency(
      certification.agency, other: certification.agencyOther)
    figures = [
      Figure.row("Number", certification.certificationNumber),
      Figure.row("Certified", certification.certifiedOn.map(DateText.date)),
    ].compactMap { $0 }
    let file = certification.file(side: CertificationSide.front.rawValue)
    let isPDF = file?.contentType == CertificationCardEdits.pdfContentType
    front = isPDF ? nil : file
    missingFrontIcon = file == nil ? .tabBadgeCheck : isPDF ? .tabFileText : .tabImageOff
  }
}
