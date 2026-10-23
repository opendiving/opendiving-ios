import OpenDivingKit
import SwiftUI

/// The titled card each section of a dive, a trip, a site and the check-in sheet sits in,
/// its title led by the section's symbol where it has one.
struct SectionCard<Content: View>: View {
  let title: String
  let systemImage: String?
  let content: Content

  init(title: String, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.systemImage = systemImage
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        if let systemImage {
          Image(systemName: systemImage)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
        }
        Text(title)
      }
      .font(.headline)
      .accessibilityElement(children: .combine)
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
      SectionCard(title: "People", systemImage: "person.2") {
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
