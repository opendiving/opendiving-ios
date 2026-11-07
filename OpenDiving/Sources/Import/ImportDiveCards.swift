import OpenDivingKit
import SwiftUI

/// The dives an import adds or changes, one card each, in a section of their own. A long import
/// is not paged, the list drawing a card only as it nears the screen.
struct ImportDiveCards: View {
  let read: LogbookImportRead
  let units: UnitSystem

  var body: some View {
    let cards = ImportDiveCard.cards(read.dives, applied: read.isApplied, units: units)
    if !cards.isEmpty {
      Section {
        ForEach(cards) { card in
          ImportDiveCardRow(card: card, units: units)
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
      }
    }
  }
}

private struct ImportDiveCardRow: View {
  let card: ImportDiveCard
  let units: UnitSystem

  @State private var showsSheet = false

  var body: some View {
    switch card.tap {
    case .sheet:
      Button {
        showsSheet = true
      } label: {
        DiveCardView(content: card.content)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(card.accessibilityLabel)
      .sheet(isPresented: $showsSheet) {
        ImportDiveSheetView(sheet: card.sheet(units: units))
      }
    case .dive(let uuid):
      // A hidden link under the card, or the list draws its chevron across it.
      ZStack {
        NavigationLink {
          DiveDetailView(diveUUID: uuid)
        } label: {
          EmptyView()
        }
        .opacity(0)
        DiveCardView(content: card.content)
      }
      .accessibilityLabel(card.accessibilityLabel)
    case .none:
      DiveCardView(content: card.content)
    }
  }
}

#Preview {
  NavigationStack {
    List {
      ImportDiveCards(read: ImportPreviewData.pending, units: .metric)
    }
  }
  .environment(DivePreviewData.session)
}
