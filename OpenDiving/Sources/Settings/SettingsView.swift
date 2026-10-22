import OpenDivingKit
import SwiftUI

/// The *Settings* tab. Placeholder.
struct SettingsView: View {
  var body: some View {
    NavigationStack {
      EmptyOrErrorView(
        status: .empty(systemImage: "gearshape", title: "Settings", message: "Not built yet.")
      )
      .navigationTitle("Settings")
    }
  }
}

#Preview {
  SettingsView()
}
