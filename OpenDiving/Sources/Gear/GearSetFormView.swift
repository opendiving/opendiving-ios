import OpenDivingKit
import SwiftUI

/// The gear set form as a screen of its own: a new set, a copy of `duplicateOf`, a set's edit from
/// its row, or a queued edit the server refused.
struct GearSetFormView: View {
  let mode: RecordFormMode<GearSetRead>
  /// With `.create`: the set the new one starts as a copy of.
  var duplicateOf: GearSetRead?
  /// The set was deleted from the form, which leaves its row nothing to show.
  var onDeleted: () -> Void = {}

  var body: some View {
    ManagedOnTheWebView(
      title: "Gear Sets", icon: .layers, message: "Gear sets are managed on the web.")
  }
}

#Preview {
  NavigationStack {
    GearSetFormView(mode: .create)
  }
}
