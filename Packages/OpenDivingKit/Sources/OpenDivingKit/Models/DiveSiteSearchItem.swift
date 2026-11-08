import Foundation

/// A site row of `GET /dive-sites/search`: the lookup row, with how far it is from the camera, how
/// its name matched and what the site's card shows beside it. The lookup row's own members read
/// straight through, `item.name`.
@dynamicMemberLookup
public struct DiveSiteSearchItem: Codable, Hashable, Sendable {
  public var site: DiveSiteLookupItem
  /// Metres from the camera the search was sent; nil without one, or for a site with no pin.
  public var distanceM: Double?
  /// `exact`, `prefix`, `contains` or `fuzzy`; nil untyped, and on a row found by its locality
  /// alone. A string, so a later value reads as sent.
  public var match: String?
  public var depthFrom: Double?
  public var depthTo: Double?
  /// Nil on a Commons record the reader has not saved.
  public var dives: DiveSiteDives?
  public var proposal: DiveSiteProposalState?

  public subscript<Value>(dynamicMember keyPath: KeyPath<DiveSiteLookupItem, Value>) -> Value {
    site[keyPath: keyPath]
  }

  enum CodingKeys: String, CodingKey {
    case distanceM, match, depthFrom, depthTo, dives, proposal
  }

  public init(
    site: DiveSiteLookupItem, distanceM: Double? = nil, match: String? = nil,
    depthFrom: Double? = nil, depthTo: Double? = nil, dives: DiveSiteDives? = nil,
    proposal: DiveSiteProposalState? = nil
  ) {
    self.site = site
    self.distanceM = distanceM
    self.match = match
    self.depthFrom = depthFrom
    self.depthTo = depthTo
    self.dives = dives
    self.proposal = proposal
  }

  public init(from decoder: any Decoder) throws {
    site = try DiveSiteLookupItem(from: decoder)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    distanceM = try c.decodeIfPresent(Double.self, forKey: .distanceM)
    match = try c.decodeIfPresent(String.self, forKey: .match)
    depthFrom = try c.decodeIfPresent(Double.self, forKey: .depthFrom)
    depthTo = try c.decodeIfPresent(Double.self, forKey: .depthTo)
    dives = try c.decodeIfPresent(DiveSiteDives.self, forKey: .dives)
    proposal = try c.decodeIfPresent(DiveSiteProposalState.self, forKey: .proposal)
  }

  public func encode(to encoder: any Encoder) throws {
    try site.encode(to: encoder)
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeIfPresent(distanceM, forKey: .distanceM)
    try c.encodeIfPresent(match, forKey: .match)
    try c.encodeIfPresent(depthFrom, forKey: .depthFrom)
    try c.encodeIfPresent(depthTo, forKey: .depthTo)
    try c.encodeIfPresent(dives, forKey: .dives)
    try c.encodeIfPresent(proposal, forKey: .proposal)
  }

  public var isWaitingForReview: Bool { proposal?.status == DiveSiteProposalStatus.waiting }
}
