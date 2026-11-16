import Foundation
import Observation

/// *Your Proposals*: the diver's proposals a page at a time, the *Withdraw* on one that waits,
/// and the switch that shows the diver's name beside one in the site's history.
@MainActor
@Observable
public final class DiveSiteProposalsModel {
  public let list: PagedList<DiveSiteProposalRead>
  public let withdrawal: ProposalWithdrawal
  /// The proposal whose choice is on its way, and the choice sent, which its switch shows until
  /// the answer lands.
  public private(set) var choosing: (proposal: UUID, showProposer: Bool)?
  /// The sentence of a choice the server refused, until the diver has read it.
  public var choiceFailure: String?

  @ObservationIgnored private let session: Session

  public init(session: Session) {
    self.session = session
    withdrawal = ProposalWithdrawal(session: session)
    list = PagedList(session: session) { client, page, itemsPerPage in
      try await client.diveSiteProposals(page: page, itemsPerPage: itemsPerPage)
    }
  }

  /// What `row`'s switch shows: the choice on its way, or the proposal's own.
  public func showsProposer(_ row: DiveSiteProposalSummary.Row) -> Bool {
    if let choosing, choosing.proposal == row.proposal { return choosing.showProposer }
    return row.showProposer ?? false
  }

  /// Sends the diver's choice for one proposal, a direct call as a withdraw is. The answer takes
  /// the row's place; a refusal leaves the row as it was and says why, and a 409, which says the
  /// proposal was decided or withdrawn meanwhile, reads the list again.
  public func showProposer(_ proposal: UUID, _ showProposer: Bool) async {
    guard choosing == nil else { return }
    choosing = (proposal, showProposer)
    defer { choosing = nil }
    choiceFailure = nil
    do {
      let answer = try await session.requireClient().updateDiveSiteProposal(
        proposal, DiveSiteProposalUpdate(showProposer: showProposer))
      list.replace(answer)
    } catch {
      let error = APIError(error)
      choiceFailure = error.message
      if case .http(status: 409, _) = error { await list.reloadWithEveryList(on: session) }
    }
  }

  /// Takes back a proposal and reads every page shown again.
  public func withdraw(_ proposal: UUID) async {
    await withdrawal.withdraw(proposal) { await list.reloadWithEveryList(on: session) }
  }
}
