import OpenDivingKit
import SwiftUI

/// The diver's contacts, each row opening the contact's form.
struct ContactListView: View {
  var body: some View {
    ManagedOnTheWebView(
      title: "Contacts", icon: .bookUser, message: "Contacts are managed on the web.")
  }
}

#Preview {
  NavigationStack {
    ContactListView()
  }
}
