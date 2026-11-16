/// `PATCH /dive-site-proposal/{uuid}`'s body: whether other divers read the diver's name beside
/// what the proposal changes in the site's history.
public struct DiveSiteProposalUpdate: Codable, Hashable, Sendable {
  public var showProposer: Bool

  public init(showProposer: Bool) {
    self.showProposer = showProposer
  }
}
