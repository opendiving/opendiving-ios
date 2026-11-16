import OpenDivingKit
import SwiftUI

/// *Your Proposals*, pushed from the sites map, under the OpenDiving Commons mark: to a diver who
/// has proposed nothing, what the Commons is and how to propose a site; to one who has, what
/// waits, what was accepted and what was declined, a tab each, with the introduction behind *i*.
struct YourProposalsView: View {
  static let title = "Your Proposals"

  @Environment(Session.self) private var session

  var body: some View {
    ProposalsContent(model: DiveSiteProposalsModel(session: session))
  }
}

nonisolated extension DiveSiteProposalTab: TabSection {}

private struct ProposalsContent: View {
  @State private var model: DiveSiteProposalsModel
  @State private var tab = DiveSiteProposalTab.proposed
  @State private var showsIntro = false
  @State private var adding = false

  init(model: DiveSiteProposalsModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    let any = model.any
    Group {
      switch any.phase {
      case .idle, .loading:
        EmptyOrErrorView(status: .loading)
      case .failed(let error):
        EmptyOrErrorView(status: .failed(message: error.message)) {
          Task { await any.load() }
        }
      case .loaded where any.items.isEmpty:
        CommonsIntroPage { adding = true }
      case .loaded:
        ProposalTabs(model: model, tab: $tab) { adding = true }
      }
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle(YourProposalsView.title)
    .navigationBarTitleDisplayMode(.inline)
    // The title names the page in the back button's history; the mark heads it on screen.
    .toolbar(removing: .title)
    .toolbar {
      if any.phase == .loaded, !any.items.isEmpty {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            showsIntro = true
          } label: {
            Label("About OpenDiving Commons", systemImage: "info.circle")
          }
        }
      }
    }
    .sheet(isPresented: $showsIntro) { CommonsIntroSheet() }
    .navigationDestination(isPresented: $adding) {
      DiveSiteFormView(mode: .create, visibility: .public)
    }
    .task { await any.load() }
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

/// The mark over the tabs, then the chosen tab's proposals.
private struct ProposalTabs: View {
  let model: DiveSiteProposalsModel
  @Binding var tab: DiveSiteProposalTab
  let add: () -> Void

  var body: some View {
    let list = model.list(tab)
    ScrollView {
      LazyVStack(spacing: 16) {
        CommonsWordmarkHeader(height: 64)
        SectionTabs(selection: $tab, showsIcons: false)
        Group {
          switch list.phase {
          case .idle, .loading:
            BubbleSpinner()
              .frame(maxWidth: .infinity)
              .padding(.vertical, 24)
          case .failed(let error):
            EmptyOrErrorView(status: .failed(message: error.message)) {
              Task { await list.load() }
            }
          case .loaded where list.items.isEmpty:
            ContentUnavailableView {
              Label(tab.emptyTitle, icon: .landmark)
            } description: {
              Text(CommonsIntro.emptyMessage)
            } actions: {
              Button(CommonsIntro.addAction, systemImage: "plus", action: add)
                .brandProminentButton()
            }
            .padding(.top, 24)
          case .loaded:
            ForEach(list.items) { proposal in
              ProposalCard(row: DiveSiteProposalSummary.row(proposal), model: model)
                .onAppear { Task { await list.loadMore(after: proposal) } }
            }
            LoadMoreFooter(list: list)
          }
        }
        .padding(.horizontal)
      }
      .padding(.bottom)
    }
    .bubbleRefreshable { await model.refresh() }
    .task(id: tab) { await list.load() }
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

#Preview("Proposals") {
  let page =
    #"{"data":[{"uuid":"01a15c10-7d3e-7b21-9a44-5e6f7a8b9c0d","kind":"new_site","#
    + #""status":"waiting","reason":null,"site":{"uuid":"01a0a521-28c5-7e34-a572-4d7324f5033b","#
    + #""name":"Tiger Reef"},"created_at":"2026-11-02T23:40:11.502113Z","decided_at":null}],"#
    + #""total_count":1,"has_more":false,"page":1,"items_per_page":50}"#
  NavigationStack {
    YourProposalsView()
  }
  .environment(
    Session.stub(transport: StubTransport(routes: ["GET dive-site-proposals": .json(page)])))
}

#Preview("None yet") {
  let empty = #"{"data":[],"total_count":0,"has_more":false,"page":1,"items_per_page":1}"#
  NavigationStack {
    YourProposalsView()
  }
  .environment(
    Session.stub(transport: StubTransport(routes: ["GET dive-site-proposals": .json(empty)])))
}
