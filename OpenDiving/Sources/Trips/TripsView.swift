import OpenDivingKit
import SwiftUI

/// The *Trips* tab. Placeholder.
struct TripsView: View {
  var body: some View {
    NavigationStack {
      EmptyOrErrorView(
        status: .empty(systemImage: "suitcase", title: "Trips", message: "Not built yet.")
      )
      .navigationTitle("Trips")
    }
  }
}

#Preview {
  TripsView()
}
