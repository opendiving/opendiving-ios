import OpenDivingKit
import SwiftUI

/// A run of dives as cards, each opening the dive's page. The cards are laid out together,
/// so a paged list asks for its next page through a ``PageEndTrigger`` after them rather
/// than from a card's `onAppear`, which a non-lazy stack runs for every card at once.
struct DiveCardLinks: View {
  let items: [DiveListItem]
  let units: UnitSystem

  var body: some View {
    VStack(spacing: 12) {
      ForEach(items) { item in
        NavigationLink {
          DiveDetailView(diveUUID: item.id)
        } label: {
          DiveCardView(content: DiveCardContent.dive(item, units: units))
        }
        .buttonStyle(.plain)
      }
    }
  }
}

#Preview {
  NavigationStack {
    DiveCardLinks(items: [], units: .metric)
  }
}
