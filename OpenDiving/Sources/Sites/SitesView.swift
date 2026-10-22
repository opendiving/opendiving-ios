import OpenDivingKit
import SwiftUI

/// The *Sites* tab. Placeholder.
struct SitesView: View {
  var body: some View {
    NavigationStack {
      EmptyOrErrorView(
        status: .empty(
          systemImage: "mappin.and.ellipse", title: "Dive sites", message: "Not built yet.")
      )
      .navigationTitle("Sites")
    }
  }
}

#Preview {
  SitesView()
}
