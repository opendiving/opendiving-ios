import OpenDivingKit
import SwiftUI

/// The web's numbering card above the dives: what a renumber would tidy in the log, and the way
/// in to doing it, where a diver is when the question occurs to them. Muted and factual, and
/// absent from a log already numbered consecutively in date order, which is most of them.
struct DiveNumberingCard: View {
  let description: String

  @State private var isRenumbering = false

  var body: some View {
    HStack(spacing: 12) {
      Label(description, systemImage: "list.number")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
      Button("Renumber") { isRenumbering = true }
        .brandBorderedButton()
        .controlSize(.small)
    }
    .padding(12)
    .background(Color.cardFill, in: .formSection)
    // The renumber tells every list over the account, this card's among them.
    .sheet(isPresented: $isRenumbering) { RenumberDivesSheet() }
  }
}

#Preview {
  DiveNumberingCard(description: "Numbered #1–#215 — 5 numbers unused, 2 dives share a number.")
    .padding()
    .background(Color.pageBackground)
    .environment(DivePreviewData.session)
}
