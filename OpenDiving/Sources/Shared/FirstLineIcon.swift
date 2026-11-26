import OpenDivingKit
import SwiftUI

/// A list row's symbol in the text's colour, centred on the first line of a title that runs to
/// more than one: the list would centre it on the whole title.
struct FirstLineIcon: View {
  let icon: OpenDivingKit.Icon

  var body: some View {
    ZStack {
      // One line in the title's font, whose middle is the first line's.
      Text(verbatim: " ")
        .hidden()
        .accessibilityHidden(true)
      Image(loaded: icon)
        // The colour itself: the list's label hands its icon the accent as the foreground, and
        // the hierarchical `.primary` resolves to that.
        .foregroundStyle(Color.primary)
    }
    .frame(maxHeight: .infinity, alignment: .top)
  }
}

#Preview {
  List {
    Label {
      VStack(alignment: .leading, spacing: 4) {
        Text("Chrome on macOS")
        Text("203.0.113.7 · Last used today, 21:08")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    } icon: {
      FirstLineIcon(icon: .monitor)
    }
  }
}
