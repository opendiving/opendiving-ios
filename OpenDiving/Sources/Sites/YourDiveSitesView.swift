import OpenDivingKit
import SwiftUI

/// Every dive site of the account's, pinned or not, most recently dived first, each opening on the
/// map.
/// A placeholder for now, which says the record is managed on the web.
struct YourDiveSitesView: View {
  var body: some View {
    ManagedOnTheWebView(
      title: "Dive Sites", icon: .diveSite, message: "Your dive sites are listed on the web.")
  }
}

#Preview {
  NavigationStack {
    YourDiveSitesView()
  }
}
