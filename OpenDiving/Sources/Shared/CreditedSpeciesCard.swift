import OpenDivingKit
import SwiftUI

/// A species card that opens the species' page, as the web's cards do. Where it carries a photo
/// its corner opens the photo's credit too: the photos are Commons files under Creative Commons
/// licences, and the card has no room for the line.
struct CreditedSpeciesCard: View {
  let speciesUUID: UUID
  /// The `?v=` of the species' photo; nil means no photo, so nothing to credit.
  let photoVersion: String?
  let content: SpeciesCardContent
  @State private var showsCredit = false

  var body: some View {
    NavigationLink {
      SpeciesDetailView(speciesUUID: speciesUUID)
    } label: {
      SpeciesCardView(content: content)
    }
    .buttonStyle(.plain)
    .overlay(alignment: .topTrailing) {
      if let photoVersion {
        Button {
          showsCredit = true
        } label: {
          Image(systemName: "info.circle")
            .font(.subheadline)
            .padding(4)
            .background(.ultraThinMaterial, in: Circle())
            .padding(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Photo credit")
        .sheet(isPresented: $showsCredit) {
          SpeciesPhotoCreditSheet(
            speciesUUID: speciesUUID, photoVersion: photoVersion, content: content)
        }
      }
    }
  }
}

#Preview {
  NavigationStack {
    ScrollView {
      VStack(spacing: 12) {
        CreditedSpeciesCard(
          speciesUUID: SpeciesPhotoCreditSheet.previewUUID, photoVersion: "ab12",
          content: SpeciesCardContent(
            commonName: "Twoband anemonefish", scientificName: "Amphiprion bicinctus",
            figures: [Figure(label: "Count", value: "2")]))
        CreditedSpeciesCard(
          speciesUUID: UUID(), photoVersion: nil,
          content: SpeciesCardContent(
            commonName: "Muraenidae", scientificName: "Muraenidae (family)")
        )
      }
      .padding()
    }
    .background(Color(.systemGroupedBackground))
  }
  .environment(SpeciesPhotoCreditSheet.previewSession)
}
