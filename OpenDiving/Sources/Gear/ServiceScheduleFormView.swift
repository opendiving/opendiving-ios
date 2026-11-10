import OpenDivingKit
import SwiftUI

/// A gear item's service schedule form: a new schedule for `gearItem`, a schedule's edit by its
/// uuid, a queued edit the server refused, or with `failedItem` a queued create the server refused.
struct ServiceScheduleFormView: View {
  /// The gear item the schedule is for.
  let gearItem: RecordRef
  /// The schedule, by its uuid, where the form opens over one.
  let mode: RecordFormMode<UUID>
  /// With `.create`: the refused create to reopen, by its outbox item's id.
  var failedItem: UUID?
  /// The schedule was deleted from the form.
  var onDeleted: () -> Void = {}

  var body: some View {
    ManagedOnTheWebView(
      title: "Service Schedule", icon: .wrench, message: "Service is managed on the web.")
  }
}

#Preview {
  NavigationStack {
    ServiceScheduleFormView(gearItem: .server(UUID()), mode: .create)
  }
}
