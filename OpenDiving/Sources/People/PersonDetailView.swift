import OpenDivingKit
import SwiftUI

/// A person's page, by their uuid.
/// A placeholder for now, which says the record is managed on the web.
struct PersonDetailView: View {
  let personUUID: UUID

  var body: some View {
    ManagedOnTheWebView(title: "Person", icon: .user, message: "People are managed on the web.")
  }
}

#Preview {
  NavigationStack {
    PersonDetailView(personUUID: UUID())
  }
}
