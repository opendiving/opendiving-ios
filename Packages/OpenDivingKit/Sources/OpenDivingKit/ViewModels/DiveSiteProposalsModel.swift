import Foundation
import Observation

/// *Your Proposals*: whether the diver has proposed anything at all, the proposals of each tab a
/// page at a time, the *Withdraw* on one that waits, and the switch that shows the diver's name
/// beside one in the site's history.
@MainActor
@Observable
public final class DiveSiteProposalsModel {
  /// One proposal of any status, withdrawn among them: none at all is what shows the page's
  /// introduction in place of the tabs.
  public let any: PagedList<DiveSiteProposalRead>
  public let withdrawal: ProposalWithdrawal
  /// The proposal whose choice is on its way, and the choice sent, which its switch shows until
  /// the answer lands.
  public private(set) var choosing: (proposal: UUID, showProposer: Bool)?
  /// The sentence of a choice the server refused, until the diver has read it.
  public var choiceFailure: String?

  @ObservationIgnored private let session: Session
  @ObservationIgnored private let lists: [DiveSiteProposalTab: PagedList<DiveSiteProposalRead>]

  public init(session: Session) {
    self.session = session
    withdrawal = ProposalWithdrawal(session: session)
    any = PagedList(session: session, itemsPerPage: 1) { client, page, itemsPerPage in
      try await client.diveSiteProposals(page: page, itemsPerPage: itemsPerPage)
    }
    lists = Dictionary(
      uniqueKeysWithValues: DiveSiteProposalTab.allCases.map { tab in
        let status = tab.status
        return (
          tab,
          PagedList(session: session) { client, page, itemsPerPage in
            try await client.diveSiteProposals(
              status: status, page: page, itemsPerPage: itemsPerPage)
          }
        )
      })
  }

  /// The proposals `tab` lists.
  public func list(_ tab: DiveSiteProposalTab) -> PagedList<DiveSiteProposalRead> {
    lists[tab]!
  }

  /// Pull-to-refresh: the account and whether there is any proposal, then every tab that has been
  /// shown, since a proposal decided meanwhile has moved from one to another.
  public func refresh() async {
    await any.refresh()
    for list in lists.values { list.accountListsChanged() }
    for list in lists.values { await list.reloading?.value }
  }

  /// What `row`'s switch shows: the choice on its way, or the proposal's own.
  public func showsProposer(_ row: DiveSiteProposalSummary.Row) -> Bool {
    if let choosing, choosing.proposal == row.proposal { return choosing.showProposer }
    return row.showProposer ?? false
  }

  /// Sends the diver's choice for one proposal, a direct call as a withdraw is. The answer takes
  /// the row's place on whichever tab holds it; a refusal leaves the row as it was and says why,
  /// and a 409, which says the proposal was decided or withdrawn meanwhile, reads every list
  /// again.
  public func showProposer(_ proposal: UUID, _ showProposer: Bool) async {
    guard choosing == nil else { return }
    choosing = (proposal, showProposer)
    defer { choosing = nil }
    choiceFailure = nil
    do {
      let answer = try await session.requireClient().updateDiveSiteProposal(
        proposal, DiveSiteProposalUpdate(showProposer: showProposer))
      for list in lists.values { list.replace(answer) }
    } catch {
      let error = APIError(error)
      choiceFailure = error.message
      if case .http(status: 409, _) = error {
        await list(.proposed).reloadWithEveryList(on: session)
      }
    }
  }

  /// Takes back a proposal and reads every list shown again: it leaves *Proposed*, and is on no
  /// tab.
  public func withdraw(_ proposal: UUID) async {
    await withdrawal.withdraw(proposal) {
      await list(.proposed).reloadWithEveryList(on: session)
    }
  }
}
