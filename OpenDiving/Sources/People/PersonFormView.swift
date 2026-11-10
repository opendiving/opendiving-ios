import OpenDivingKit
import SwiftUI

/// The person form as a screen of its own: a new person, a person's page's edit, or a queued edit
/// the server refused.
/// A placeholder for now, which says the record is managed on the web.
struct PersonFormView: View {
  let mode: RecordFormMode<PersonRead>
  /// The person was deleted from the form, which leaves their page nothing to show.
  var onDeleted: () -> Void = {}

  var body: some View {
    ManagedOnTheWebView(title: "Person", icon: .user, message: "People are managed on the web.")
  }
}

#Preview {
  NavigationStack {
    PersonFormView(mode: .create)
  }
}
