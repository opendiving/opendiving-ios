import Foundation

/// One accepted change to a Commons record, as `GET /dive-site/{uuid}/history` lists them,
/// newest first.
public struct DiveSiteHistoryEntryRead: Codable, Hashable, Sendable, Identifiable {
  public var id: UUID { uuid }

  public let uuid: UUID
  /// ``DiveSiteHistoryKind``, as the API spells it.
  public let kind: String
  public let createdAt: DiveTimestamp
  /// The display name of whoever made the change, where one is shown: the proposer's by their
  /// own choice, or the reviewer's on a correction.
  public let madeBy: String?
  /// Each shared member that changed; empty when added.
  public let details: [DiveSiteHistoryDetail]
}

/// One shared member an entry changed, its values as the site's shared members read them. A pin
/// that moved names both `latitude` and `longitude`.
public struct DiveSiteHistoryDetail: Codable, Hashable, Sendable {
  /// The member's name on the wire.
  public let field: String
  public let old: ImportChangeValue
  public let new: ImportChangeValue
}

/// The kinds of entry the API writes. Strings, so a later kind still reads.
public enum DiveSiteHistoryKind {
  public static let added = "added"
  public static let changed = "changed"
}
