import OpenDivingKit
import SwiftUI

/// The people in the diver's address book.
struct PeopleListView: View {
  var body: some View {
    ManagedOnTheWebView(title: "People", icon: .users, message: "People are managed on the web.")
  }
}

#Preview {
  NavigationStack {
    PeopleListView()
  }
}
