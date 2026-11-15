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
    .modifier(FormHeaderType())
    .foregroundStyle(.secondary)
    .padding(.horizontal, 16)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isHeader)
  }
}

/// The type a form draws its section headers in, which each system sets its own: a semibold
/// body from iOS 26, as `UIListContentConfiguration.header()` reads there, and an uppercased
/// footnote before.
private struct FormHeaderType: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 26, *) {
      content.font(.headline)
    } else {
      content.font(.footnote).textCase(.uppercase)
    }
  }
}

#Preview {
  VStack(alignment: .leading) {
    SectionTitle(title: "People", icon: .users)
    SectionTitle(title: "Diving")
  }
  .padding()
}
