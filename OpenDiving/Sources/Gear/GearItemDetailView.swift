import OpenDivingKit
import SwiftUI

/// A gear item's page, by its uuid.
/// A placeholder for now, which says the record is managed on the web.
struct GearItemDetailView: View {
  let gearItemUUID: UUID

  var body: some View {
    ManagedOnTheWebView(title: "Gear", icon: .backpack, message: "Gear is managed on the web.")
  }
}

#Preview {
  NavigationStack {
    GearItemDetailView(gearItemUUID: UUID())
  }
}
