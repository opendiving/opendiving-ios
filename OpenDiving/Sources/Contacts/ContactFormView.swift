import OpenDivingKit
import SwiftUI

/// The contact form as a screen of its own, which a contact has in place of a page: a new contact,
/// a contact's edit from its row, or a queued edit the server refused.
/// A placeholder for now, which says the record is managed on the web.
struct ContactFormView: View {
  let mode: RecordFormMode<ContactRead>
  /// The contact was deleted from the form, which leaves its row nothing to show.
  var onDeleted: () -> Void = {}

  var body: some View {
    ManagedOnTheWebView(
      title: "Contact", icon: .bookUser, message: "Contacts are managed on the web.")
  }
}

#Preview {
  NavigationStack {
    ContactFormView(mode: .create)
  }
}
