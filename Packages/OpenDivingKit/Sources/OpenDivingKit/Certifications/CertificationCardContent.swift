import Foundation

/// One certification as a card on More's *Certifications* (`CertificationCard`): its level over
/// the foot of its front with the expiry badge beside it, and the agency under, as a dive's
/// title and facts.
public struct CertificationCardContent: Hashable, Sendable, Identifiable {
  public let id: UUID
  public let name: String
  /// Expiring soon or expired; nil for a card with no expiry or one far from it.
  public let badge: Badge?
  /// The agency, where it has one.
  public let facts: [Fact]
  /// The front, drawn behind the details; nil with none stored or a PDF, which is never drawn.
  public let front: CertificationFileInfo?
  /// The icon in the water where no front is drawn: none stored, a PDF, or one that could not
  /// be had.
  public let missingFrontIcon: Icon

  public init(_ certification: CertificationRead, today: CalendarDate) {
    id = certification.uuid
    name = certification.name
    badge = CertificationExpiry(expiresOn: certification.expiresOn, today: today).map {
      Badge($0.label, style: $0 == .expired ? .destructive : .coral)
    }
    let agency = VocabularyLabels.certificationAgency(
      certification.agency, other: certification.agencyOther)
    facts = agency.map { [Fact(text: $0)] } ?? []
    let file = certification.file(side: CertificationSide.front.rawValue)
    let isPDF = file?.contentType == CertificationCardEdits.pdfContentType
    front = isPDF ? nil : file
    missingFrontIcon = file == nil ? .tabBadgeCheck : isPDF ? .tabFileText : .tabImageOff
  }
}
