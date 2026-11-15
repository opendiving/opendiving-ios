import OpenDivingKit
import SwiftUI

/// A page section's title, standing over its card as a form's section header stands over its
/// rows, led by the section's symbol where it has one.
struct SectionTitle: View {
  let title: String
  var icon: Icon?

  var body: some View {
    HStack(spacing: 6) {
      if let icon {
        Image(icon).accessibilityHidden(true)
      }
      Text(title)
    }
    .font(.footnote)
    .foregroundStyle(.secondary)
    .padding(.horizontal, 16)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isHeader)
  }
}

#Preview {
  VStack(alignment: .leading) {
    SectionTitle(title: "People", icon: .users)
    SectionTitle(title: "Diving")
  }
  .padding()
}
