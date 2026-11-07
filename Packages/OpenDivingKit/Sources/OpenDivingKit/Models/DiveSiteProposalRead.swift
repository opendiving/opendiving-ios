import Foundation

/// One of the diver's proposals on `GET /dive-site-proposals`.
public struct DiveSiteProposalRead: Codable, Hashable, Sendable, Identifiable {
  public var id: UUID { uuid }

  public let uuid: UUID
  public let kind: String
  public let status: String
  /// Why it was declined.
  public let reason: String?
  /// The site it is on: once accepted, the Commons record it became or joined.
  public let site: DiveSiteProposalSite
  public let createdAt: DiveTimestamp
  public let decidedAt: DiveTimestamp?
}

public struct DiveSiteProposalSite: Codable, Hashable, Sendable {
  public let uuid: UUID
  public let name: String
}
