import OpenDivingKit
import SwiftUI

/// A species' page, by its uuid: its photo and the photo's credit, the dives with it and its
/// taxonomy.
struct SpeciesDetailView: View {
  let speciesUUID: UUID

  var body: some View {
    ManagedOnTheWebView(title: "Species", icon: .fish, message: "Marine life is shown on the web.")
  }
}

#Preview {
  NavigationStack {
    SpeciesDetailView(speciesUUID: UUID())
  }
}
