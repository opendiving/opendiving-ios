import SwiftUI

/// The heading a run of a list card's rows is filed under: a letter on the people and contacts
/// lists, a gear type's group on the gear list.
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
    ListSectionHeader(title: "Exposure")
  }
  .background(Color.cardFill)
}
