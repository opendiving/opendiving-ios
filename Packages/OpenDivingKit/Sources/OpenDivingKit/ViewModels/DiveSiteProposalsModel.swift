import Foundation
import Observation

/// *Your Proposals*: whether the diver has proposed anything at all, the proposals of each tab a
/// page at a time, and the *Withdraw* on one that waits.
@MainActor
@Observable
public final class DiveSiteProposalsModel {
  /// One proposal of any status, withdrawn among them: none at all is what shows the page's
  /// introduction in place of the tabs.
  public let any: PagedList<DiveSiteProposalRead>
  public let withdrawal: ProposalWithdrawal

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

  /// Takes back a proposal and reads every list shown again: it leaves *Proposed*, and is on no
  /// tab.
  public func withdraw(_ proposal: UUID) async {
    await withdrawal.withdraw(proposal) {
      await list(.proposed).reloadWithEveryList(on: session)
    }
  }
}
