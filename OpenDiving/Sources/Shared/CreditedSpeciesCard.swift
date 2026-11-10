import OpenDivingKit
import SwiftUI

/// A species card that opens the species' page, as the web's cards do. The page carries its
/// photo's credit as visible text, which is how a card too small for the line credits it: the
/// photos are Commons files under Creative Commons licences, which accept a credit one link away.
struct CreditedSpeciesCard: View {
  let speciesUUID: UUID
  let content: SpeciesCardContent

  var body: some View {
    NavigationLink {
      SpeciesDetailView(speciesUUID: speciesUUID)
    } label: {
      SpeciesCardView(content: content)
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  NavigationStack {
    ScrollView {
      VStack(spacing: 12) {
        CreditedSpeciesCard(
          speciesUUID: UUID(),
          content: SpeciesCardContent(
            commonName: "Twoband anemonefish", scientificName: "Amphiprion bicinctus",
            figures: [Figure(label: "Count", value: "2")]))
        CreditedSpeciesCard(
          speciesUUID: UUID(),
          content: SpeciesCardContent(
            commonName: "Muraenidae", scientificName: "Muraenidae (family)")
        )
      }
      .padding()
    }
    .background(Color(.systemGroupedBackground))
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
