import OpenDivingKit
import SwiftUI

/// A certification's page, by its uuid: both sides and the card's fields, with Edit in the top bar.
/// A placeholder for now, which says the record is managed on the web.
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
