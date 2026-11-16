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

  private var showsTabs: Bool {
    model.any.phase == .loaded && !model.any.items.isEmpty
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
    .toolbar {
      // The title names the page in the back button's history; the mark heads it on screen, and
      // on the tabs it becomes the bar's own title. Removing the title would remove that too.
      if !showsTabs {
        ToolbarItem(placement: .principal) {
          Color.clear.frame(width: 1, height: 1)
        }
      }
      if showsTabs {
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

/// The mark over the tabs, then the chosen tab's proposals. Scrolled up, the mark and *Commons*
/// fly into the navigation bar as its title while *OpenDiving* fades on the way, and the tabs stay
/// pinned under the bar.
private struct ProposalTabs: View {
  let model: DiveSiteProposalsModel
  @Binding var tab: DiveSiteProposalTab
  let add: () -> Void

  private static let content = "ProposalTabsContent"
  private static let gap: CGFloat = 16

  @State private var offset: CGFloat = 0
  /// The scroll view's height less its insets, which its container size already leaves out.
  @State private var visibleHeight: CGFloat = 0
  /// How far the page scrolls before the tabs reach the bar: the head's height and the gap under
  /// it.
  @State private var travel: CGFloat = 0
  @State private var scrollFrame = CGRect.zero
  @State private var contentFrame = CGRect.zero
  /// In the page's content, where they stand with it at rest.
  @State private var mark = CGRect.zero
  @State private var word = CGRect.zero
  /// On screen.
  @State private var barMark = CGRect.zero
  @State private var barWord = CGRect.zero

  var body: some View {
    let list = model.list(tab)
    ScrollView {
      LazyVStack(spacing: Self.gap, pinnedViews: [.sectionHeaders]) {
        CommonsWordmarkHeader(
          height: 64, in: Self.content, onMarkFrame: { mark = $0 }, onWordFrame: { word = $0 }
        )
        // The flying copy stands in for it from the first point of the scroll.
        .opacity(progress > 0 ? 0 : 1)
        .onGeometryChange(for: CGFloat.self) {
          $0.size.height
        } action: {
          travel = $0 + Self.gap
        }
        Section {
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
        } header: {
          SectionTabs(selection: $tab, showsIcons: false)
            // On the page's own fill, which what scrolls passes under.
            .background(Color(.systemGroupedBackground))
        }
      }
      .padding(.bottom)
      // Tall enough for the head to go all the way into the bar however short the list.
      .frame(minHeight: visibleHeight + travel, alignment: .top)
      .coordinateSpace(.named(Self.content))
      .onGeometryChange(for: CGRect.self) {
        $0.frame(in: .global)
      } action: {
        contentFrame = $0
      }
    }
    .onScrollGeometryChange(for: CGFloat.self) {
      $0.contentOffset.y + $0.contentInsets.top
    } action: {
      offset = $1
    }
    .onScrollGeometryChange(for: CGFloat.self) {
      $0.containerSize.height
    } action: {
      visibleHeight = $1
    }
    .onGeometryChange(for: CGRect.self) {
      $0.frame(in: .global)
    } action: {
      scrollFrame = $0
    }
    // Over the scroll rather than in it: the name goes straight from its place to the bar while
    // the page moves away under it, clear of the blur the bar lays over the scroll's content.
    .overlay(alignment: .topLeading) { flyingName }
    .toolbar {
      ToolbarItem(placement: .principal) {
        CommonsBarTitle(onMarkFrame: { barMark = $0 }, onWordFrame: { barWord = $0 })
          .opacity(progress >= 1 ? 1 : 0)
      }
    }
    .bubbleRefreshable { await model.refresh() }
    .task(id: tab) { await list.load() }
  }

  /// How far the head has gone into the bar, from none at rest to all once the tabs reach it.
  private var progress: Double {
    guard travel > 0 else { return 0 }
    return min(max(Double(offset / travel), 0), 1)
  }

  /// The mark, *OpenDiving* and *Commons* `progress` of the way from where the head stands at rest
  /// to the bar's title, *OpenDiving* fading as it goes.
  @ViewBuilder private var flyingName: some View {
    let share = progress
    if share > 0, share < 1, barWord != .zero {
      let markFrame = atRest(mark).interpolated(to: onScroll(barMark), by: share)
      let wordFrame = atRest(word).interpolated(to: onScroll(barWord), by: share)
      let openDiving = CommonsName.openDivingFrame(commons: wordFrame)
      ZStack(alignment: .topLeading) {
        // At the default text size, so the mark is drawn at the size given rather than scaled.
        CommonsMark(side: markFrame.width)
          .environment(\.dynamicTypeSize, .large)
          .offset(x: markFrame.minX, y: markFrame.minY)
        Image("Wordmark")
          .resizable()
          .frame(width: openDiving.width, height: openDiving.height)
          .opacity(1 - share)
          .offset(x: openDiving.minX, y: openDiving.minY)
        Image("CommonsWord")
          .resizable()
          .frame(width: wordFrame.width, height: wordFrame.height)
          .offset(x: wordFrame.minX, y: wordFrame.minY)
      }
      .foregroundStyle(Color.primary.opacity(0.75))
      .allowsHitTesting(false)
      .accessibilityHidden(true)
    }
  }

  /// `frame`, in the content, as it stands in the scroll view with the page at rest.
  private func atRest(_ frame: CGRect) -> CGRect {
    let contentTopAtRest = contentFrame.minY + offset
    return frame.offsetBy(
      dx: contentFrame.minX - scrollFrame.minX, dy: contentTopAtRest - scrollFrame.minY)
  }

  /// `frame`, on screen, in the scroll view.
  private func onScroll(_ frame: CGRect) -> CGRect {
    frame.offsetBy(dx: -scrollFrame.minX, dy: -scrollFrame.minY)
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
