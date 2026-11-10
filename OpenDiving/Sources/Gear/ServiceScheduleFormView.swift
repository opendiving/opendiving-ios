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
  /// With `.create`: the gear's type, whose usual schedule a new one starts from.
  var gearType: String?

  @Environment(Session.self) private var session

  var body: some View {
    switch mode {
    case .create:
      ServiceScheduleForm(
        model: RecordSheetModel(
          outbox: OutboxModel(session: session),
          values: ServiceScheduleFormValues(
            gearItem: gearItem, gearType: gearType, today: CalendarDate.today()),
          failedItem: failedItem),
        onDeleted: onDeleted)
    case .edit(let uuid):
      loaded(uuid, failedItem: nil)
    case .failed(let item, let uuid):
      loaded(uuid, failedItem: item)
    }
  }

  private func loaded(_ uuid: UUID, failedItem: UUID?) -> some View {
    RecordFormLoader {
      try await GearServiceModel.schedule(uuid, of: gearItem, session: session)
    } content: { schedule in
      ServiceScheduleForm(
        model: RecordSheetModel(
          outbox: OutboxModel(session: session), editing: .server(schedule.uuid),
          read: ServiceScheduleFormValues(editing: schedule), failedItem: failedItem),
        onDeleted: onDeleted)
    }
  }
}

private struct ServiceScheduleForm: View {
  @State var model: RecordSheetModel<ServiceScheduleFormValues>
  let onDeleted: () -> Void

  var body: some View {
    RecordSheetForm(
      title: model.isEditing ? "Edit Service Schedule" : "New Service Schedule",
      isReopened: model.isReopened, createLabel: "Create schedule", isPushed: true,
      failure: model.failure, saveError: model.saveError, deletion: deletion, save: save
    ) {
      Section {
        Picker("Service type *", selection: $model.values.kind) {
          ForEach(GearServiceKinds.options(including: model.values.kind), id: \.self) { kind in
            Text(GearServiceKinds.label(kind)).tag(kind)
          }
        }
        FieldMessage(model.message("kind"))
        VStack(alignment: .leading, spacing: 6) {
          TextBox(
            label: "Label", placeholder: "e.g. First stage", text: $model.values.label,
            message: model.message("label"))
          Text("Optional. Lets one item carry two rules of the same type.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      Section {
        CalendarDateField(label: "In service since *", date: $model.values.startsOn)
        FieldMessage(model.message("starts_on"))
        Text(
          "Counted from until you log a service. For a used cylinder, use the date stamped on it."
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
      }
      Section {
        IntervalBox(
          label: "Every (months)", placeholder: "e.g. 12", value: $model.values.intervalMonths,
          message: model.message("interval_months"))
        IntervalBox(
          label: "Every (dives)", placeholder: "e.g. 100", value: $model.values.intervalDives,
          message: model.message("interval_dives"))
        IntervalBox(
          label: "Every (hours)", placeholder: "e.g. 50", value: $model.values.intervalHours,
          message: model.message("interval_hours"))
      } footer: {
        Text(
          "Set any of the three — whichever comes first is what makes this due. Hours count the "
            + "time spent diving with this item, from your logged dives. These are common starting "
            + "points, not manufacturer or legal advice: check what your kit and your local rules "
            + "actually require.")
      }
    }
  }

  private var deletion: RecordDeletion? {
    guard model.canDelete else { return nil }
    return RecordDeletion(
      title: "Delete service schedule", message: RecordDeletionText.serviceSchedule,
      delete: model.delete, onDeleted: onDeleted)
  }

  private func save() -> Bool {
    model.save() != nil
  }
}

/// One of the schedule's three intervals: a whole number, blank for none.
private struct IntervalBox: View {
  let label: String
  let placeholder: String
  @Binding var value: Int?
  var message: String?

  @State private var text = ""
  @FocusState private var focused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      InlineField(label, focus: $focused) {
        TextField(label, text: $text, prompt: Text(placeholder))
          .keyboardType(.numberPad)
          .multilineTextAlignment(.trailing)
          .labelsHidden()
          .focused($focused)
          .onChange(of: text) { _, typed in
            guard focused else { return }
            value = ServiceScheduleFormValues.interval(typed)
          }
      }
      FieldMessage(message)
    }
    .onAppear { text = value.map(String.init) ?? "" }
    .onChange(of: value) { _, now in if !focused { text = now.map(String.init) ?? "" } }
  }
}

#Preview {
  NavigationStack {
    ServiceScheduleFormView(gearItem: .server(UUID()), mode: .create, gearType: "regulator")
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
