import OpenDivingKit
import SwiftUI

/// A card's title, the facts under it and its figures, in one colour and with a glow in the
/// card's own colour, as the web's, to lift them off whatever the glass leaves showing.
struct CardDetailLines: View {
  let title: String
  var isCourse = false
  var rating: Int?
  let facts: [Fact]
  let figures: [Figure]

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      VStack(alignment: .leading, spacing: 2) {
        TitleLine(title: title, isCourse: isCourse, rating: rating)
        FactsLine(facts: facts, color: .primary)
      }
      FiguresRow(figures: figures)
        .padding(.top, 2)
    }
    .shadow(color: Color(.systemBackground).opacity(0.6), radius: 3)
  }
}

#Preview {
  CardDetailLines(
    title: "#212 Blue Hole", isCourse: true, rating: 4,
    facts: [Fact(text: "Apr 4, 2021, 10:04"), Fact(text: "Dahab, Egypt")],
    figures: [
      Figure(label: "Dive time", value: "48 min"), Figure(label: "Max depth", value: "31 m"),
    ]
  )
  .padding()
  .background(Color(red: 163 / 255, green: 206 / 255, blue: 205 / 255))
}
