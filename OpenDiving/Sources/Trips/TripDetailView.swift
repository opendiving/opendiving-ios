import OpenDivingKit
import SwiftUI

/// One trip's page, pushed from the dive page and the trips list. Placeholder.
struct TripDetailView: View {
  let tripUUID: UUID

  var body: some View {
    EmptyOrErrorView(status: .empty(systemImage: "suitcase", title: "Trip", message: nil))
      .navigationTitle("Trip")
  }
}

#Preview {
  NavigationStack {
    TripDetailView(tripUUID: UUID())
  }
}
