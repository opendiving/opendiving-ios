import OpenDivingKit
import SwiftUI

/// A certification's page, by its uuid: both sides and the card's fields, with Edit in the top bar.
struct CertificationDetailView: View {
  let certificationUUID: UUID

  var body: some View {
    ManagedOnTheWebView(
      title: "Certification", icon: .badgeCheck, message: "Certifications are managed on the web.")
  }
}

#Preview {
  NavigationStack {
    CertificationDetailView(certificationUUID: UUID())
  }
}
