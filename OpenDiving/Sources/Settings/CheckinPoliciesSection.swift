import OpenDivingKit
import SwiftUI

/// *Dive Insurance*: the policies in the diver's order, each a row that drags to a new place and
/// swipes away.
struct CheckinPoliciesSection: View {
  @Bindable var model: CheckinDetailsModel

  var body: some View {
    let policies = model.draft.insurancePolicies
    CheckinGroupSection(model: model, group: .insurance) {
      if policies.isEmpty {
        Text("No insurance policies yet.").foregroundStyle(.secondary)
      }
      SortableRows(
        items: $model.draft.insurancePolicies, identity: \.id,
        title: { $0.provider.isEmpty ? "Policy" : $0.provider },
        row: { _, policy in row(policy.id, movable: policies.count > 1) })
      if model.canAddRow(to: .insurance) {
        Button("Add a policy") { model.draft.insurancePolicies.append(.init()) }
          .accentRow()
      }
    }
  }

  private func row(_ id: UUID, movable: Bool) -> some View {
    let policy = binding(id)
    return VStack(alignment: .leading, spacing: 12) {
      TextBox(
        label: "Provider", placeholder: "DAN Europe, DiveAssure…", text: policy.provider,
        message: model.problems[.policyProvider(id)])
      TextBox(
        label: "Policy number", text: policy.number, message: model.problems[.policyNumber(id)],
        verbatim: true)
      CalendarDateField(label: "Expires on", date: policy.expiresOn)
      HStack {
        Button("Remove") { model.draft.insurancePolicies.removeAll { $0.id == id } }
          .dangerRow()
          .buttonStyle(.borderless)
          .accessibilityLabel(
            "Remove \(policy.wrappedValue.provider.isEmpty ? "policy" : policy.wrappedValue.provider)"
          )
        Spacer()
        if movable { DragHandle() }
      }
    }
    .padding(.vertical, 4)
  }

  /// By identity, as the rows may have moved since the row drew.
  private func binding(_ id: UUID) -> Binding<CheckinDetailsDraft.Policy> {
    Binding(
      get: { model.draft.insurancePolicies.first { $0.id == id } ?? .init(id: id) },
      set: { policy in
        guard let index = model.draft.insurancePolicies.firstIndex(where: { $0.id == id })
        else { return }
        model.draft.insurancePolicies[index] = policy
      })
  }
}

#Preview {
  Form {
    CheckinPoliciesSection(
      model: CheckinDetailsModel(session: Session.stub(transport: StubTransport(routes: [:]))))
  }
}
