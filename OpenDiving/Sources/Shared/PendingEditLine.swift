import OpenDivingKit
import SwiftUI

/// On a record's page while an edit of it waits to sync.
struct PendingEditLine: View {
  var body: some View {
    Label(OfflineText.pendingEdit, systemImage: "arrow.triangle.2.circlepath")
      .font(.footnote)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

#Preview {
  PendingEditLine()
}
