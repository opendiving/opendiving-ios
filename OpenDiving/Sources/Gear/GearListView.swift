import OpenDivingKit
import SwiftUI

/// The diver's gear, archived items among them, and their gear sets.
/// A placeholder for now, which says the record is managed on the web.
struct GearListView: View {
  var body: some View {
    ManagedOnTheWebView(title: "Gear", icon: .backpack, message: "Gear is managed on the web.")
  }
}

#Preview {
  NavigationStack {
    GearListView()
  }
}
