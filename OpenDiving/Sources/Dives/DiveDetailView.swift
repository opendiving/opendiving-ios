import OpenDivingKit
import SwiftUI

/// One dive's page, pushed from any list of dive cards. Placeholder.
struct DiveDetailView: View {
  let diveUUID: UUID

  var body: some View {
    EmptyOrErrorView(
      status: .empty(systemImage: "water.waves", title: "Dive", message: "Not built yet.")
    )
    .navigationTitle("Dive")
  }
}

#Preview {
  NavigationStack {
    DiveDetailView(diveUUID: UUID())
  }
}
