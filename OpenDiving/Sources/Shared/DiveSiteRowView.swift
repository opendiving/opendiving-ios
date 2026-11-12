import OpenDivingKit
import SwiftUI

/// One of the diver's sites as a row, on More's *Dive Sites* and a species' page: its name, its
/// facts, the diver's dives there, a proposal waiting on it, and a Commons record's mark and
/// credit.
struct DiveSiteRowView: View {
  let content: YourDiveSiteRowContent

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(content.title)
        .font(.body.weight(.medium))
        .foregroundStyle(Color.primary)
      FactsLine(facts: content.facts)
      if let figures = content.figures {
        Text(figures)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      if content.isWaitingForReview {
        BadgeView(DiveSiteProposalSummary.waitingForReview, style: .outline)
      }
      if content.isCommons {
        HStack(spacing: 8) {
          DiveSiteMarkBadge(mark: .commons)
          if let credit = content.credit {
            AttributionLine(credits: [credit])
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    .contentShape(Rectangle())
  }
}

#Preview {
  NavigationStack {
    YourDiveSitesView()
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
