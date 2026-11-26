import SwiftUI

/// The letter a run of a list card's rows is filed under, as the people and contacts lists draw
/// it.
struct ListSectionHeader: View {
  let title: String

  var body: some View {
    Text(title)
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
    ListSectionHeader(title: "A")
    ListSectionHeader(title: "#")
  }
  .background(Color.cardFill)
}
