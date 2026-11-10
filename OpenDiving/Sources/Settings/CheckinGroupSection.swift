import OpenDivingKit
import SwiftUI

/// One group of the check-in details: its title and line, its fields, and the save that sends
/// them alone, with what stopped it or that it landed underneath.
struct CheckinGroupSection<Fields: View>: View {
  let model: CheckinDetailsModel
  let group: CheckinGroup
  @ViewBuilder let fields: Fields

  var body: some View {
    let saving = model.isSaving(group)
    Section {
      fields
        .disabled(saving)
      Button {
        Task { await model.save(group) }
      } label: {
        HStack(spacing: 8) {
          if saving { BubbleSpinner() }
          Text(saving ? "Saving…" : "Save changes").bold()
        }
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .tint(.brandTeal)
      .controlSize(.large)
      .disabled(saving)
      .listRowInsets(EdgeInsets())
      .listRowBackground(Color.clear)
    } header: {
      VStack(alignment: .leading, spacing: 2) {
        Text(group.title).font(.headline).foregroundStyle(.primary)
        Text(group.description)
      }
      .textCase(nil)
    } footer: {
      if let failure = model.failures[group] {
        FieldMessage(failure)
      } else if model.saved.contains(group) {
        FieldMessage(group.savedMessage, isNote: true)
      }
    }
  }
}

#Preview {
  Form {
    CheckinGroupSection(
      model: CheckinDetailsModel(session: Session.stub(transport: StubTransport(routes: [:]))),
      group: .about
    ) {
      Text("Fields")
    }
  }
}
