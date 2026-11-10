import OpenDivingKit
import SwiftUI

/// The diver's gear, archived items among them, and their gear sets.
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
