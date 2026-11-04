import SwiftUI

/// The mark at the end of a row that reorders by long-press and drag.
struct DragHandle: View {
  var body: some View {
    Image(systemName: "line.3.horizontal")
      .foregroundStyle(.tertiary)
      .accessibilityHidden(true)
  }
}

#Preview {
  DragHandle()
}
