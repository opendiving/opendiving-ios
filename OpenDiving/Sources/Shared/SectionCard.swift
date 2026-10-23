import OpenDivingKit
import SwiftUI

/// The titled card each section of a dive, a trip, a site and the check-in sheet sits in.
struct SectionCard<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.headline)
        .accessibilityAddTraits(.isHeader)
      content
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
  }
}

#Preview {
  ScrollView {
    VStack(spacing: 16) {
      SectionCard(title: "People") {
        PersonRowView(content: PersonRowContent(name: "Ana Diaz", username: "ana", role: "Buddy"))
      }
      SectionCard(title: "Notes") {
        Text("Drift along the wall, turtle at 18 m.")
      }
    }
    .padding()
  }
  .background(Color(.systemGroupedBackground))
}
