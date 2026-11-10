import OpenDivingKit
import SwiftUI

/// The diver's life list, most recently seen first.
struct MarineLifeListView: View {
  var body: some View {
    ManagedOnTheWebView(
      title: "Marine Life", icon: .fish, message: "Marine life is shown on the web.")
  }
}

#Preview {
  NavigationStack {
    MarineLifeListView()
  }
}
