import OpenDivingKit
import SwiftUI

/// The card each section of a dive, a trip, a site and the check-in sheet sits in, under its
/// title.
struct SectionCard<Content: View>: View {
  let title: String
  let icon: Icon?
  let content: Content

  init(title: String, icon: Icon? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.icon = icon
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      SectionTitle(title: title, icon: icon)
      VStack(alignment: .leading, spacing: 12) {
        content
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.cardFill, in: .formSection)
    }
  }
}

#Preview {
  ScrollView {
    VStack(spacing: 16) {
      SectionCard(title: "People", icon: .users) {
        PersonRowView(content: PersonRowContent(name: "Ana Diaz", username: "ana", role: "Buddy"))
      }
      SectionCard(title: "Notes") {
        Text("Drift along the wall, turtle at 18 m.")
      }
    }
    .padding()
  }
  .background(Color.pageBackground)
}
