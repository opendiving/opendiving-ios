import SwiftUI

/// The OpenDiving Commons mark with its name on two lines to its right, the two as tall as each
/// other.
struct CommonsWordmarkHeader: View {
  /// Scaled with the text size up to where the pair still fits a phone's width.
  @ScaledMetric private var height: CGFloat
  private let baseHeight: CGFloat

  init(height: CGFloat = 80) {
    baseHeight = height
    _height = ScaledMetric(wrappedValue: height, relativeTo: .title)
  }

  var body: some View {
    HStack(spacing: 16) {
      CommonsMark(side: baseHeight, relativeTo: .title)
      // The web's wordmark face, Outfit Bold, as outlines: the app carries no copy of the font.
      Image("CommonsWordmark")
        .resizable()
        .scaledToFit()
        .frame(height: height)
        .foregroundStyle(Color.primary.opacity(0.75))
    }
    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
    CommonsWordmarkHeader(height: 64)
  }
  .padding()
}
