import OpenDivingKit
import SwiftUI

/// A person's page, by their uuid.
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
