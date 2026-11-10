import OpenDivingKit
import SwiftUI

/// One species as a card: its photo behind its names — a fish where there is none — then
/// the diver's note and the figures. The photo is decorative; the name says what it is.
struct SpeciesCardView: View {
  let content: SpeciesCardContent

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      photo
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .clipped()
        // A photo filled into the frame runs past it untouched by the clip, and would take taps
        // meant for whatever stands above or below the card.
        .contentShape(Rectangle())
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 4) {
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
          .padding(.top, 2)
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder private var photo: some View {
    if let data = content.photo, let image = UIImage(data: data) {
      Image(uiImage: image)
        .resizable()
        .scaledToFill()
    } else {
      ZStack {
        Color(.tertiarySystemGroupedBackground)
        Image(.fish)
          .font(.largeTitle)
          .foregroundStyle(.secondary)
      }
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
