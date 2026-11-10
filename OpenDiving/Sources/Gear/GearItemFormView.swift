import OpenDivingKit
import SwiftUI

/// The gear item form as a screen of its own: new gear, a gear item's page's edit, or a queued edit
/// the server refused.
struct GearItemFormView: View {
  let mode: RecordFormMode<GearItemRead>
  /// The item was deleted from the form, which leaves the page it was opened from nothing to show.
  var onDeleted: () -> Void = {}

  var body: some View {
    ManagedOnTheWebView(title: "Gear", icon: .backpack, message: "Gear is managed on the web.")
  }
}

#Preview {
  NavigationStack {
    GearItemFormView(mode: .create)
  }
}
