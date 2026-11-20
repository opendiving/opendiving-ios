import OpenDivingKit
import SwiftUI

/// A page section's title, standing over its card as a form's section header stands over its
/// rows, led by the section's symbol where it has one, with a line under it, aligned with the
/// title rather than the symbol, where it has a subtitle.
struct SectionTitle: View {
  let title: String
  var icon: Icon?
  var subtitle: String?

  var body: some View {
    VStack(alignment: .titleLeading, spacing: 2) {
      HStack(spacing: 6) {
        if let icon {
          Image(icon).accessibilityHidden(true)
        }
        Text(title)
          .alignmentGuide(.titleLeading) { $0[.leading] }
      }
      .modifier(FormHeaderType())
      if let subtitle {
        Text(subtitle)
          .font(.subheadline)
          .alignmentGuide(.titleLeading) { $0[.leading] }
      }
    }
    .foregroundStyle(.secondary)
    .padding(.horizontal, 16)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isHeader)
  }
}

extension HorizontalAlignment {
  private enum TitleLeading: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> CGFloat { context[.leading] }
  }

  /// Where a ``SectionTitle``'s title starts, past its symbol.
  fileprivate static let titleLeading = HorizontalAlignment(TitleLeading.self)
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
    SectionTitle(title: "Dahab", icon: .mapPin, subtitle: "3 – 10 May 2026")
  }
  .padding()
}
