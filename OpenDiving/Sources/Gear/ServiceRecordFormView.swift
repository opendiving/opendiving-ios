import OpenDivingKit
import SwiftUI

/// A gear item's service form: a service logged for `gearItem`, for `schedule` where it is logged
/// against one, a service's edit by its uuid, a queued edit the server refused, or with
/// `failedItem` a queued create the server refused.
struct ServiceRecordFormView: View {
  /// The gear item serviced.
  let gearItem: RecordRef
  /// The service, by its uuid, where the form opens over one.
  let mode: RecordFormMode<UUID>
  /// With `.create`: the schedule the service is logged against, by its uuid.
  var schedule: UUID?
  /// With `.create`: the refused create to reopen, by its outbox item's id.
  var failedItem: UUID?
  /// The service was deleted from the form.
  var onDeleted: () -> Void = {}

  var body: some View {
    ManagedOnTheWebView(
      title: "Service", icon: .clipboardCheck, message: "Service is managed on the web.")
  }
}

#Preview {
  NavigationStack {
    ServiceRecordFormView(gearItem: .server(UUID()), mode: .create)
  }
}
