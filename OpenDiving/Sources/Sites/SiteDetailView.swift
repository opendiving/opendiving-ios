import OpenDivingKit
import SwiftUI

/// One dive site's page, pushed from the dive page and the sites list. Placeholder.
struct SiteDetailView: View {
  let siteUUID: UUID

  var body: some View {
    EmptyOrErrorView(status: .empty(systemImage: "mappin.and.ellipse", title: "Site", message: nil))
      .navigationTitle("Site")
  }
}

#Preview {
  NavigationStack {
    SiteDetailView(siteUUID: UUID())
  }
}
