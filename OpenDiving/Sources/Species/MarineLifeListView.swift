import OpenDivingKit
import SwiftUI

/// The diver's life list, most recently seen first.
/// A placeholder for now, which says the record is managed on the web.
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
