import OpenDivingKit
import SwiftUI

/// One of the diver's sites as a trip's card, on More's *Dive Sites* and a species' page: a map
/// of its pin over its name, facts and figures, then a proposal waiting on it, and a Commons
/// record's mark and credit.
struct YourDiveSiteCard: View {
  let content: YourDiveSiteCardContent

  var body: some View {
    RecordCardView(content: content.card, icon: .tabDiveSite) {
      if content.isWaitingForReview || content.isCommons {
        HStack(spacing: 8) {
          if content.isWaitingForReview {
            BadgeView(DiveSiteProposalSummary.waitingForReview, style: .outline)
          }
          if content.isCommons {
            DiveSiteMarkBadge(mark: .commons)
            if let credit = content.credit {
              AttributionLine(credits: [credit])
            }
          }
        }
      }
    }
    .contentShape(Rectangle())
  }
}

#Preview {
  NavigationStack {
    YourDiveSitesView()
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
