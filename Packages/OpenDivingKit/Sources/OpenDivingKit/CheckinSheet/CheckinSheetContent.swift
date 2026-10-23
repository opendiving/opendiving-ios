import Foundation

/// The cached sheet as the Cards view draws it, every value already a string, section for
/// section as the web's `/checkin` reads; a section with nothing in it is an empty list.
public struct CheckinSheetContent: Hashable, Sendable {
  public let name: String
  /// Nil draws no portrait and no frame.
  public let portrait: CheckinSheetFile?
  /// Date of birth, phone and email, under the name.
  public let about: [Figure]
  /// Dives logged, max depth and last dive.
  public let diving: [Figure]
  /// One group of rows per policy.
  public let insurance: [[Figure]]
  /// One group of rows per contact, in call order.
  public let emergencyContacts: [[Figure]]
  public let cards: [CheckinCardContent]
  /// `Last updated Oct 23, 2026, 14:05`.
  public let lastUpdated: String

  /// `today` decides which cards read as expiring; `timeZone` is the one the *last
  /// updated* time prints in.
  public init(_ sheet: CheckinSheet, today: CalendarDate, timeZone: TimeZone = .current) {
    name = sheet.name
    portrait = sheet.portrait
    let details = sheet.details
    about = [
      Figure.row("Date of birth", details.dateOfBirth.map(DateText.date)),
      Figure.row("Phone", details.phone),
      Figure.row("Email", details.email),
    ].compactMap { $0 }
    diving = [
      Figure.row("Dives logged", String(sheet.totalDives)),
      Figure.row("Max depth", UnitFormat.depth(sheet.maxDepth, sheet.units)),
      Figure.row("Last dive", sheet.lastDiveStart.map(DateText.diveDate)),
    ].compactMap { $0 }
    insurance = details.insurancePolicies.map { policy in
      [
        Figure.row("Provider", policy.provider),
        Figure.row("Policy number", policy.number),
        Figure.row("Expires", policy.expiresOn.map(DateText.date)),
      ].compactMap { $0 }
    }.filter { !$0.isEmpty }
    emergencyContacts = details.emergencyContacts.map { contact in
      [
        Figure.row("Name", contact.name),
        Figure.row("Phone", contact.phone),
        Figure.row("Relationship", contact.relationship),
      ].compactMap { $0 }
    }.filter { !$0.isEmpty }
    cards = sheet.cards.map { CheckinCardContent($0, today: today) }
    lastUpdated = "Last updated " + DateText.dateTime(sheet.updatedAt, in: timeZone)
  }
}
