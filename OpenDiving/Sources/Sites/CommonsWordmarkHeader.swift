import SwiftUI

/// The OpenDiving Commons mark over its name, as the sign-in screen heads itself with the brand's.
struct CommonsWordmarkHeader: View {
  var markSide: CGFloat = 72

  @ScaledMetric(relativeTo: .title) private var wordmarkHeight: CGFloat = 24

  var body: some View {
    VStack(spacing: 12) {
      CommonsMark(side: markSide, relativeTo: .title)
      // The web's wordmark face, Outfit Bold, as outlines: the app carries no copy of the font.
      Image("CommonsWordmark")
        .resizable()
        .scaledToFit()
        .frame(maxHeight: wordmarkHeight)
        .foregroundStyle(Color.primary.opacity(0.75))
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 12)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("OpenDiving Commons")
    .accessibilityAddTraits(.isHeader)
  }
}

#Preview {
  VStack(spacing: 32) {
    CommonsWordmarkHeader()
    CommonsWordmarkHeader(markSide: 48)
  }
  .padding()
}
