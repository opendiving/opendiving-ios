import OpenDivingKit
import SwiftUI

/// *Your Proposals*, pushed from the sites map: what the diver has proposed for OpenDiving
/// Commons and what became of it, a page at a time.
struct YourProposalsView: View {
  static let title = "Your Proposals"

  @Environment(Session.self) private var session

  var body: some View {
    ProposalList(model: DiveSiteProposalsModel(session: session))
      .navigationTitle(Self.title)
      .navigationBarTitleDisplayMode(.inline)
  }
}

private struct ProposalList: View {
  @State private var model: DiveSiteProposalsModel

  init(model: DiveSiteProposalsModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    let list = model.list
    Group {
      switch list.phase {
      case .idle, .loading:
        EmptyOrErrorView(status: .loading)
      case .failed(let error):
        EmptyOrErrorView(status: .failed(message: error.message)) {
          Task { await list.load() }
        }
      case .loaded where list.items.isEmpty:
        EmptyOrErrorView(
          status: .empty(
            icon: .landmark, title: "No proposals yet",
            message: "What you propose for OpenDiving Commons shows here."))
      case .loaded:
        ScrollView {
          LazyVStack(spacing: 12) {
            ForEach(list.items) { proposal in
              ProposalCard(row: DiveSiteProposalSummary.row(proposal), model: model)
                .onAppear { Task { await list.loadMore(after: proposal) } }
            }
            LoadMoreFooter(list: list)
          }
          .padding()
        }
      }
    }
    .background(Color(.systemGroupedBackground))
    .bubbleRefreshable { await list.refresh() }
    .task { await list.load() }
    .proposalWithdrawalAlert(model.withdrawal)
  }
}

/// The site, opening its page, then the kind and the date, the outcome with any reason, and
/// *Withdraw* on one that waits.
private struct ProposalCard: View {
  let row: DiveSiteProposalSummary.Row
  let model: DiveSiteProposalsModel

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      NavigationLink {
        SiteDetailView(siteUUID: row.siteUUID)
      } label: {
        Text(row.siteName)
          .font(.headline)
          .multilineTextAlignment(.leading)
      }
      .accentRow()
      Text(row.kind + " · " + row.date)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Text(row.outcome)
        .font(.subheadline)
      if let reason = row.reason {
        Text(reason)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      if let proposal = row.withdrawable {
        ProposalWithdrawButton(
          proposal: proposal, withdrawal: model.withdrawal, withdraw: model.withdraw)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
  }
}

#Preview {
  NavigationStack {
    YourProposalsView()
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
