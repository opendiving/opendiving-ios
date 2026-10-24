import SwiftUI

/// A record created on the phone that has not reached the server yet.
struct PendingMark: View {
  var body: some View {
    Image(systemName: "icloud.slash")
      .font(.caption)
      .foregroundStyle(.secondary)
      .accessibilityLabel("Not yet on the server")
  }
}

#Preview {
  PendingMark()
}
