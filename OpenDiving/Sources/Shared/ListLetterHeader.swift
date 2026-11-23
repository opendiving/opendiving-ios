import SwiftUI

/// The letter a run of a list card's rows is filed under, as the people and contacts lists draw
/// it.
struct ListLetterHeader: View {
  let letter: String

  var body: some View {
    Text(letter)
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.top, 10)
      .padding(.bottom, 2)
      .accessibilityAddTraits(.isHeader)
  }
}

#Preview {
  VStack(spacing: 0) {
    ListLetterHeader(letter: "A")
    ListLetterHeader(letter: "#")
  }
  .background(Color.cardFill)
}
