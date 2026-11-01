import SwiftUI

/// The credits the data shown owes, as its licence asks, one line for every source: each is a
/// markdown link from the API, rendered rather than printed raw. A link shares the text's
/// colour, as on the web, so in copy it is underlined; over a map, by the owner's call, it is
/// not.
struct AttributionLine: View {
  let credits: [String]
  var underline = true

  var body: some View {
    Text(
      credits.map { Self.rendered($0, underline: underline) }.reduce(AttributedString()) {
        line, credit in
        line.characters.isEmpty ? credit : line + AttributedString(" · ") + credit
      }
    )
    .font(.caption2)
    .foregroundStyle(.secondary)
    .tint(Color(.secondaryLabel))
  }

  static func rendered(_ credit: String, underline: Bool = true) -> AttributedString {
    var rendered = (try? AttributedString(markdown: credit)) ?? AttributedString(credit)
    if underline {
      for run in rendered.runs where run.link != nil {
        rendered[run.range].underlineStyle = .single
      }
    }
    return rendered
  }
}

#Preview {
  AttributionLine(credits: [
    "[Data © OpenStreetMap contributors, ODbL 1.0.](https://osm.org/copyright)"
  ])
}
