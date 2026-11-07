import Foundation
import Observation

/// *Your Proposals*: the diver's proposals a page at a time, and the *Withdraw* on one that
/// waits.
@MainActor
@Observable
public final class DiveSiteProposalsModel {
  public let list: PagedList<DiveSiteProposalRead>
  public let withdrawal: ProposalWithdrawal

  @ObservationIgnored private let session: Session

  public init(session: Session) {
    self.session = session
    withdrawal = ProposalWithdrawal(session: session)
    list = PagedList(session: session) { client, page, itemsPerPage in
      try await client.diveSiteProposals(page: page, itemsPerPage: itemsPerPage)
    }
  }

  /// Takes back a proposal and reads every page shown again.
  public func withdraw(_ proposal: UUID) async {
    await withdrawal.withdraw(proposal) { await list.reloadWithEveryList(on: session) }
  }
}
