import OpenDivingKit
import SwiftUI

/// The diver's certifications, each card over its front image.
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
