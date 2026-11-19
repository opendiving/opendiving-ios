/// A tab of *Your Proposals*: the proposals in one status. A withdrawn proposal is on none.
public enum DiveSiteProposalTab: Hashable, Sendable, CaseIterable {
  case proposed, accepted, declined

  public var title: String {
    switch self {
    case .proposed: "Proposed"
    case .accepted: "Accepted"
    case .declined: "Declined"
    }
  }

  /// The status the tab's list asks the server for.
  public var status: String {
    switch self {
    case .proposed: DiveSiteProposalStatus.waiting
    case .accepted: DiveSiteProposalStatus.accepted
    case .declined: DiveSiteProposalStatus.declined
    }
  }

  /// What the tab says when it has nothing to list.
  public var emptyTitle: String {
    switch self {
    case .proposed: "Nothing waiting for review"
    case .accepted: "No accepted proposals yet"
    case .declined: "No declined proposals"
    }
  }
}
