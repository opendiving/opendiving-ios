import OpenDivingKit
import SwiftUI

/// The *Dives* tab: the logbook, newest first. Placeholder.
struct DivesView: View {
  var body: some View {
    NavigationStack {
      EmptyOrErrorView(
        status: .empty(systemImage: "water.waves", title: "Dives", message: "Not built yet.")
      )
      .navigationTitle("Dives")
    }
  }
}

#Preview {
  DivesView()
}
