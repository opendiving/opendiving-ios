import SwiftUI

/// The credits the data shown owes, as its licence asks, one line for every source: each is a
/// markdown link from the API, rendered rather than printed raw.
struct AttributionLine: View {
  let credits: [String]

  var body: some View {
    Text(
      credits.map(Self.rendered).reduce(AttributedString()) { line, credit in
        line.characters.isEmpty ? credit : line + AttributedString(" · ") + credit
      }
    )
    .font(.caption2)
    .foregroundStyle(.secondary)
  }

  static func rendered(_ credit: String) -> AttributedString {
    (try? AttributedString(markdown: credit)) ?? AttributedString(credit)
  }
}

#Preview {
  AttributionLine(credits: [
    "[Data © OpenStreetMap contributors, ODbL 1.0.](https://osm.org/copyright)"
  ])
}
