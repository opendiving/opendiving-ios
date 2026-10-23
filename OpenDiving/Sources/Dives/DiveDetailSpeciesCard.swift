import OpenDivingKit
import SwiftUI

/// The species spotted on the dive, in spotting order, each with its photo where it has one.
struct DiveDetailSpeciesCard: View {
  let sightings: [DiveDetailContent.Sighting]
  /// The photo's bytes for a species and its version, or nil.
  let photo: (UUID, String) async -> Data?

  var body: some View {
    SectionCard(title: "Species Spotted", systemImage: "fish") {
      VStack(spacing: 8) {
        ForEach(sightings) { sighting in
          SightingView(sighting: sighting, photo: photo)
        }
      }
    }
  }
}

private struct SightingView: View {
  let sighting: DiveDetailContent.Sighting
  let photo: (UUID, String) async -> Data?
  @State private var bytes: Data?

  var body: some View {
    var card = sighting.card
    card.photo = bytes
    return CreditedSpeciesCard(
      speciesUUID: sighting.id, photoVersion: sighting.photoVersion, content: card
    )
    .task(id: sighting.photoVersion) {
      // A null version is the whole photo contract: no photo, and no request.
      guard let version = sighting.photoVersion else { return }
      bytes = await photo(sighting.id, version)
    }
  }
}

#Preview {
  ScrollView {
    DiveDetailSpeciesCard(sightings: DivePreviewData.content.sightings) { _, _ in nil }
      .padding()
  }
  .background(Color(.systemGroupedBackground))
}
