import OpenDivingKit
import SwiftUI

/// A species card that, where it carries a photo, opens the photo's credit on a tap. The
/// photos are Commons files under Creative Commons licences, and the card has no room for the
/// line, so the card links to a sheet that shows it, as the web's cards link to the species'
/// page.
struct CreditedSpeciesCard: View {
  let speciesUUID: UUID
  /// The `?v=` of the species' photo; nil means no photo, so nothing to credit.
  let photoVersion: String?
  let content: SpeciesCardContent
  @State private var showsCredit = false

  var body: some View {
    if let photoVersion {
      Button {
        showsCredit = true
      } label: {
        SpeciesCardView(content: content)
          .overlay(alignment: .topTrailing) {
            Image(systemName: "info.circle")
              .font(.subheadline)
              .padding(4)
              .background(.ultraThinMaterial, in: Circle())
              .padding(8)
              .accessibilityHidden(true)
          }
      }
      .buttonStyle(.plain)
      .accessibilityHint("Shows the photo's credit")
      .sheet(isPresented: $showsCredit) {
        SpeciesPhotoCreditSheet(
          speciesUUID: speciesUUID, photoVersion: photoVersion, content: content)
      }
    } else {
      SpeciesCardView(content: content)
    }
  }
}

#Preview {
  ScrollView {
    VStack(spacing: 12) {
      CreditedSpeciesCard(
        speciesUUID: SpeciesPhotoCreditSheet.previewUUID, photoVersion: "ab12",
        content: SpeciesCardContent(
          commonName: "Twoband anemonefish", scientificName: "Amphiprion bicinctus",
          figures: [Figure(label: "Count", value: "2")]))
      CreditedSpeciesCard(
        speciesUUID: UUID(), photoVersion: nil,
        content: SpeciesCardContent(commonName: "Muraenidae", scientificName: "Muraenidae (family)")
      )
    }
    .padding()
  }
  .background(Color(.systemGroupedBackground))
  .environment(SpeciesPhotoCreditSheet.previewSession)
}
