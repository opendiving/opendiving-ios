import OpenDivingKit
import SwiftUI

/// A credit line as plain visible text, its licence and source underlined links. Each part is a
/// text run, never markup: a photo's author is a Commons user's own text.
struct CreditText: View {
  let credit: PhotoCreditContent

  var body: some View {
    Text(Self.line(credit))
      .font(.footnote)
      .foregroundStyle(.secondary)
      .tint(Color(.secondaryLabel))
  }

  static func line(_ credit: PhotoCreditContent) -> AttributedString {
    credit.runs.reduce(into: AttributedString()) { line, run in
      var part = AttributedString(run.text)
      if let url = run.url {
        part.link = url
        part.underlineStyle = .single
      }
      line += part
    }
  }
}

#Preview {
  CreditText(
    credit: PhotoCreditContent(runs: [
      .init("Photo by Jane Doe"), .init(" · "),
      .init("CC BY-SA 4.0", url: URL(string: "https://creativecommons.org/licenses/by-sa/4.0")),
    ])
  )
  .padding()
}
