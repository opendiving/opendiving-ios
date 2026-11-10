import OpenDivingKit
import SwiftUI

/// The gear item form as a screen of its own: new gear, a gear item's page's edit, or a queued edit
/// the server refused. As the web's dialog, it carries no delete: the page's menu does, with
/// *Archive instead* beside it.
struct GearItemFormView: View {
  let mode: RecordFormMode<GearItemRead>

  @Environment(Session.self) private var session

  var body: some View {
    switch mode {
    case .create:
      form(
        RecordSheetModel(outbox: OutboxModel(session: session), values: GearItemFormValues()))
    case .edit(let item):
      form(edit(item, failedItem: nil))
    case .failed(let item, let uuid):
      RecordFormLoader {
        try await session.requireClient().gearItem(uuid)
      } content: { gearItem in
        form(edit(gearItem, failedItem: item))
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

  private func form(_ model: RecordSheetModel<GearItemFormValues>) -> some View {
    GearItemSheetForm(
      model: model, lookups: LookupsModel(session: session),
      units: RecordEntryUnits(session: session), isPushed: true, onCreated: { _ in })
  }
}

#Preview {
  NavigationStack {
    GearItemFormView(mode: .create)
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
