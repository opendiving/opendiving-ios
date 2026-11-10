import Foundation

/// Who a site belongs to, as the API spells it. A string rather than an enum, so a later kind of
/// owner reads as nobody's Commons record instead of failing the whole list.
public enum DiveSiteOwner {
  public static let account = "account"
  public static let commons = "opendivingcommons"
}

/// A dive site, with the summary of the diver's own dives there. On a Commons record the diver
/// has not saved, the notes and the tags are empty and the summary is zero.
public struct DiveSiteRead: Codable, Hashable, Sendable, Identifiable {
  public var id: UUID { uuid }

  public let uuid: UUID
  public let name: String
  public let latitude: Double?
  public let longitude: Double?
  public let notes: String
  public let otherNames: [String]
  public let externalIds: [ExternalIdRead]
  /// Metres.
  public let depthFrom: Double?
  public let depthTo: Double?
  public let waterType: String?
  /// Whole metres above sea level.
  public let altitude: Int?
  public let entryTypes: [String]
  public let tags: [String]
  public let location: LocationRead?
  public let diveCount: Int
  public let lastDivedOn: CalendarDate?
  /// Metres.
  public let maxDiveDepth: Double?
  public let speciesCount: Int
  public let averageRating: Double?
  public let owner: String
  /// Whether the site is on the diver's list.
  public let saved: Bool
  /// The credit a Commons record's source asks for, as `[label](href)`; nil on the diver's own.
  public let attribution: String?
  /// The reader's latest proposal on the site, while it waits or once declined.
  public let proposal: DiveSiteProposalState?
  /// The Commons record this site of the diver's own shares a registry entry with.
  public let commonsMatch: DiveSiteCommonsMatch?
  public let createdAt: DiveTimestamp

  public var isCommons: Bool { owner == DiveSiteOwner.commons }

  /// A Commons record off the diver's list: its panel shows it, and nothing of it can be edited.
  public var isUnsavedCommons: Bool { isCommons && !saved }

  /// The reader's proposal of this site of theirs waits for a reviewer.
  public var isWaitingForReview: Bool { proposal?.status == DiveSiteProposalStatus.waiting }
}
