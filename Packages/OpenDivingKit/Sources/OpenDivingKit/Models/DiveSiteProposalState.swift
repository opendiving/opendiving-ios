import Foundation

/// What a proposal asks for, as the API spells it. Strings rather than enums, so a later kind
/// reads as sent instead of failing the whole read.
public enum DiveSiteProposalKind {
  public static let newSite = "new_site"
  public static let change = "change"
}

/// Where a proposal stands, as the API spells it, for the same reason.
public enum DiveSiteProposalStatus {
  public static let waiting = "waiting"
  public static let accepted = "accepted"
  public static let declined = "declined"
  public static let withdrawn = "withdrawn"
}

/// The reader's own proposal on a site, as the site's read carries it: while it waits, or once
/// declined until a newer one exists.
public struct DiveSiteProposalState: Codable, Hashable, Sendable {
  public let uuid: UUID
  public let kind: String
  public let status: String
  /// Why it was declined.
  public let reason: String?
  public let createdAt: DiveTimestamp
}
