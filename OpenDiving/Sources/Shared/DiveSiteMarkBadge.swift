import OpenDivingKit
import SwiftUI

/// A site's mark as the finder's rows and its panel show it: an outlined badge with the mark's
/// icon and name, read as one label.
struct DiveSiteMarkBadge: View {
  let mark: DiveSiteMark

  var body: some View {
    BadgeView(mark.label, style: .outline) { DiveSiteMarkIcon(mark: mark) }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(mark.accessibilityLabel)
  }
}

#Preview {
  HStack {
    ForEach(DiveSiteMark.allCases.reversed(), id: \.self) { DiveSiteMarkBadge(mark: $0) }
  }
  .padding()
}
