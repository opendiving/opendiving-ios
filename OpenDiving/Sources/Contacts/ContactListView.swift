import OpenDivingKit
import SwiftUI

/// The diver's contacts, each row opening the contact's form.
/// A placeholder for now, which says the record is managed on the web.
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
