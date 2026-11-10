import OpenDivingKit
import SwiftUI

/// A screen for a record the phone does not show or change yet: its title, and the sentence
/// that says where it is managed.
struct ManagedOnTheWebView: View {
  let title: String
  let icon: OpenDivingKit.Icon
  let message: String

  var body: some View {
    EmptyOrErrorView(status: .empty(icon: icon, title: title, message: message))
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  NavigationStack {
    ManagedOnTheWebView(title: "Gear", icon: .backpack, message: "Gear is managed on the web.")
  }
}
