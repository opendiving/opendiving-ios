import OpenDivingKit
import SwiftUI

/// A species' page, by its uuid: its photo and the photo's credit, the dives with it and its
/// taxonomy.
/// A placeholder for now, which says the record is managed on the web.
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
