import OpenDivingKit
import SwiftUI

/// The diver's certifications, each card over its front image.
/// A placeholder for now, which says the record is managed on the web.
struct CertificationListView: View {
  var body: some View {
    ManagedOnTheWebView(
      title: "Certifications", icon: .badgeCheck, message: "Certifications are managed on the web.")
  }
}

#Preview {
  NavigationStack {
    CertificationListView()
  }
}
