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
    .alert(
      DiveSiteProposalSummary.showProposerRefused,
      isPresented: Binding(
        get: { model.choiceFailure != nil }, set: { if !$0 { model.choiceFailure = nil } })
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(model.choiceFailure ?? "")
    }
  }
}

/// The site, opening it on the map, then the kind and the date, the outcome with any reason,
/// *Withdraw* on one that waits, and the switch on one that can show the diver's name.
private struct ProposalCard: View {
  let row: DiveSiteProposalSummary.Row
  let model: DiveSiteProposalsModel

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      NavigationLink {
        SiteMapView(siteUUID: row.siteUUID)
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
      if row.showProposer != nil {
        Toggle(
          DiveSiteProposalSummary.showProposerLabel,
          isOn: Binding(
            get: { model.showsProposer(row) },
            set: { shown in Task { await model.showProposer(row.proposal, shown) } })
        )
        .font(.subheadline)
        .tint(.brandTeal)
        .disabled(model.choosing != nil)
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
