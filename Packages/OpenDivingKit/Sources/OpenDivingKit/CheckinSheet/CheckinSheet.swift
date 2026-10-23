import Foundation

/// The web's check-in sheet as last refreshed from one server, kept on the phone so that it
/// reads at a counter with no signal and after the session has ended.
public struct CheckinSheet: Codable, Hashable, Sendable {
  public let name: String
  /// The account's units, kept here because sign-out drops the remembered account and the
  /// signed-out sheet still prints *Max depth* in them.
  public let units: UnitSystem
  public let details: CheckinDetailsRead
  public let totalDives: Int
  /// Metres.
  public let maxDepth: Double
  /// The newest dive's `start_time`, whose own calendar day is *Last dive*.
  public let lastDiveStart: DiveTimestamp?
  public let portrait: CheckinSheetFile?
  /// The server's order: newest `certified_on` first, dateless last.
  public let cards: [CheckinSheetCard]
  public let updatedAt: Date

  public init(
    name: String, units: UnitSystem, details: CheckinDetailsRead, totalDives: Int,
    maxDepth: Double, lastDiveStart: DiveTimestamp?, portrait: CheckinSheetFile?,
    cards: [CheckinSheetCard], updatedAt: Date
  ) {
    self.name = name
    self.units = units
    self.details = details
    self.totalDives = totalDives
    self.maxDepth = maxDepth
    self.lastDiveStart = lastDiveStart
    self.portrait = portrait
    self.cards = cards
    self.updatedAt = updatedAt
  }
}
