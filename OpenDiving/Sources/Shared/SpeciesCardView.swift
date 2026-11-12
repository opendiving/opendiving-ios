import OpenDivingKit
import SwiftUI

/// One species as a card, as a site's and a trip's: its photo framed on the card's band — the water
/// and a fish where there is none — under its names, the diver's note and the figures on glass in its
/// foot. The photo is decorative; the name says what it is.
struct SpeciesCardView: View {
  let content: SpeciesCardContent

  var body: some View {
    BackdropCardView { frame in
      if let data = content.photo, let image = UIImage(data: data) {
        // Centred on the band the details leave showing, rather than on the card they cover the
        // foot of.
        PlacedPhotoView(data: data, image: image) { photo, card in
          .card(
            photoWidth: photo.width, photoHeight: photo.height, width: card.width,
            band: CardBackdropFrame.band)
        }
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
      ForEach(PlacedPhotoView.previewPhotos, id: \.self) { photo in
        SpeciesCardView(
          content: SpeciesCardContent(
            photo: photo, commonName: "Sea goldie", scientificName: "Pseudanthias squamipinnis",
            figures: [Figure(label: "Dives", value: "4")]))
      }
    }
    .padding()
  }
  .background(Color(.systemGroupedBackground))
}
