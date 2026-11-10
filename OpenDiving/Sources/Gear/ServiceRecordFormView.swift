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

  @Environment(Session.self) private var session

  var body: some View {
    switch mode {
    case .create:
      if let schedule, failedItem == nil {
        RecordFormLoader {
          try await GearServiceModel.schedule(schedule, of: gearItem, session: session)
        } content: { read in
          create(schedule: read)
        }
      } else {
        create(schedule: nil)
      }
    case .edit(let uuid):
      loaded(uuid, failedItem: nil)
    case .failed(let item, let uuid):
      loaded(uuid, failedItem: item)
    }
  }

  private func create(schedule: GearServiceScheduleRead?) -> some View {
    form(
      RecordSheetModel(
        outbox: OutboxModel(session: session),
        values: ServiceRecordFormValues(
          gearItem: gearItem, schedule: schedule, today: CalendarDate.today()),
        failedItem: failedItem))
  }

  private func loaded(_ uuid: UUID, failedItem: UUID?) -> some View {
    RecordFormLoader {
      try await GearServiceModel.record(uuid, of: gearItem, session: session)
    } content: { record in
      form(
        RecordSheetModel(
          outbox: OutboxModel(session: session), editing: .server(record.uuid),
          read: ServiceRecordFormValues(editing: record), failedItem: failedItem))
    }
  }

  private func form(_ model: RecordSheetModel<ServiceRecordFormValues>) -> some View {
    ServiceRecordForm(model: model, lookups: LookupsModel(session: session), onDeleted: onDeleted)
  }
}

private struct ServiceRecordForm: View {
  @State var model: RecordSheetModel<ServiceRecordFormValues>
  @State var lookups: LookupsModel
  let onDeleted: () -> Void

  var body: some View {
    RecordSheetForm(
      title: model.isEditing ? "Edit Service" : "Log Service", isReopened: model.isReopened,
      createLabel: "Log service", isPushed: true, failure: model.failure,
      saveError: model.saveError, deletion: deletion, save: { model.save() != nil }
    ) {
      Section {
        Picker("Service type *", selection: $model.values.kind) {
          ForEach(GearServiceKinds.options(including: model.values.kind), id: \.self) { kind in
            Text(GearServiceKinds.label(kind)).tag(kind)
          }
        }
        FieldMessage(model.message("kind"))
        CalendarDateField(label: "Serviced on *", date: $model.values.servicedOn)
        FieldMessage(model.message("serviced_on"))
      }
      Section {
        // The shop is a contact picked again next year; the person, a name typed once.
        RecordPicker(
          label: "Serviced at", placeholder: "Select a shop...",
          searchPrompt: FormPicker.contact.searchPrompt, addLabel: "Add shop...",
          rows: lookups.contacts, selection: $model.values.contact
        ) { made in
          NewContactSheet(roles: ["shop"], onCreated: made)
        }
        TextBox(
          label: "Serviced by", placeholder: "A technician's name, or self",
          text: $model.values.performedBy, message: model.message("performed_by"))
      }
      Section {
        NotesField(
          placeholder: "Parts replaced, cost, test pressure...", text: $model.values.notes,
          error: model.message("notes"))
      }
    }
  }

  private var deletion: RecordDeletion? {
    guard model.canDelete else { return nil }
    return RecordDeletion(
      title: "Delete service record", message: RecordDeletionText.serviceRecord,
      delete: model.delete, onDeleted: onDeleted)
  }
}

#Preview {
  NavigationStack {
    ServiceRecordFormView(gearItem: .server(UUID()), mode: .create)
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
