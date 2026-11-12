import OpenDivingKit
import SwiftUI

/// One species as a card, as a site's and a trip's: its photo filling the card — the water and a
/// fish where there is none — under its names, the diver's note and the figures on glass in its
/// foot. The photo is decorative; the name says what it is.
struct SpeciesCardView: View {
  let content: SpeciesCardContent

  var body: some View {
    BackdropCardView { frame in
      if let data = content.photo, let image = UIImage(data: data) {
        // Filled into the card and clipped to it, as a photo's own size would set the card's.
        Color.clear
          .overlay {
            Image(uiImage: image)
              .resizable()
              .scaledToFill()
          }
          .clipped()
          .accessibilityHidden(true)
      } else {
        UnplacedBackdropView(icon: .fish, coveredBottom: frame.coveredBottom)
      }
    } details: {
      VStack(alignment: .leading, spacing: 2) {
        Text(content.commonName)
          .font(.headline)
        if content.scientificName != content.commonName {
          Text(content.scientificName)
            .font(.caption)
            .italic()
        }
        if let note = content.note {
          Text(note)
            .font(.caption)
        }
        FiguresRow(figures: content.figures)
          .padding(.top, 4)
      }
      // The glow the other cards' details have, lifting them off what the glass leaves showing.
      .shadow(color: Color(.systemBackground).opacity(0.6), radius: 3)
    }
  }
}

#Preview {
  ScrollView {
    VStack(spacing: 12) {
      SpeciesCardView(
        content: SpeciesCardContent(
          commonName: "Napoleon wrasse", scientificName: "Cheilinus undulatus (species)",
          figures: [Figure(label: "Count", value: "2")], note: "Followed us the whole dive"))
      SpeciesCardView(
        content: SpeciesCardContent(
          commonName: "Pterois", scientificName: "Pterois",
          figures: [
            Figure(label: "Dives", value: "14"), Figure(label: "Last seen", value: "Jun 3, 2024"),
          ]
        ))
    }
    .padding()
  }
  .background(Color(.systemGroupedBackground))
}
