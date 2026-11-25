import OpenDivingKit
import SwiftUI

/// The gear item form as a screen of its own: new gear, a gear item's page's edit, or a queued edit
/// the server refused.
struct GearItemFormView: View {
  let mode: RecordFormMode<GearItemRead>
  /// The gear was deleted from the form, which leaves the page it was opened from nothing to show.
  var onDeleted: () -> Void = {}

  @Environment(Session.self) private var session

  var body: some View {
    switch mode {
    case .create:
      form(
        RecordSheetModel(outbox: OutboxModel(session: session), values: GearItemFormValues()))
    case .edit(let item):
      form(edit(item, failedItem: nil), item: item)
    case .failed(let item, let uuid):
      RecordFormLoader {
        try await session.requireClient().gearItem(uuid)
      } content: { gearItem in
        form(edit(gearItem, failedItem: item), item: gearItem)
      }
    }
  }

  private func edit(_ item: GearItemRead, failedItem: UUID?)
    -> RecordSheetModel<GearItemFormValues>
  {
    RecordSheetModel(
      outbox: OutboxModel(session: session), editing: .server(item.uuid),
      read: GearItemFormValues(editing: item), failedItem: failedItem)
  }

  private func form(_ model: RecordSheetModel<GearItemFormValues>, item: GearItemRead? = nil)
    -> some View
  {
    GearItemSheetForm(
      model: model, lookups: LookupsModel(session: session),
      units: RecordEntryUnits(session: session), isPushed: true, item: item, onCreated: { _ in },
      onDeleted: onDeleted)
  }
}

#Preview {
  NavigationStack {
    GearItemFormView(mode: .create)
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
