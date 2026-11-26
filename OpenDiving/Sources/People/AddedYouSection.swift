import OpenDivingKit
import SwiftUI

/// *Added you* over More's *People*, absent while empty: each diver who has the diver in their
/// people and whom the diver has not added, by picture, name and `@username`, with *Add*, *Hide*
/// and *Disconnect*, which need the server.
struct AddedYouSection: View {
  let model: AddedYouModel
  @State private var adding: AddedYouRow?

  var body: some View {
    let rows = model.shown
    if !rows.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text(AddedYouModel.title)
          .font(.headline)
          .accessibilityAddTraits(.isHeader)
        Text(AddedYouModel.explainer)
          .font(.footnote)
          .foregroundStyle(.secondary)
        VStack(spacing: 0) {
          ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
            if index > 0 {
              ListRowDivider(leading: ListRowIcon.textInset, trailing: 12)
            }
            AddedYouRowView(model: model, row: row) { adding = row }
          }
        }
        .background(Color.cardFill, in: .formSection)
        .clipShape(.formSection)
        if let failure = model.failure {
          FieldMessage(failure)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .sheet(item: $adding) { row in ConnectPersonSheet(account: row) }
    }
  }
}

/// One diver under *Added you*: their picture, name and username, and the row's actions.
private struct AddedYouRowView: View {
  let model: AddedYouModel
  let row: AddedYouRow
  let add: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      ConnectedPictureView(picture: .of(row), side: ListRowIcon.side)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(row.name)
          .font(.headline)
        Text("@" + row.username)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .combine)
      if model.acting == row.uuid {
        BubbleSpinner()
      } else {
        Button(AddedYouModel.add, action: add)
          .brandBorderedButton(.accentText)
          .controlSize(.small)
          .disabled(model.acting != nil)
          .needsServer()
        Menu {
          Button(AddedYouModel.hide, systemImage: "eye.slash") {
            Task { await model.hide(row) }
          }
          Button(
            AddedYouModel.disconnect, systemImage: "person.crop.circle.badge.xmark",
            role: .destructive
          ) {
            model.confirmingDisconnect = row
          }
        } label: {
          Label("More for " + row.name, systemImage: "ellipsis")
            .labelStyle(.iconOnly)
            .accentRow()
            .frame(minWidth: 32, minHeight: 32)
            .contentShape(.rect)
        }
        .disabled(model.acting != nil)
        .needsServer()
      }
    }
    .padding(12)
    .confirmationDialog(
      AddedYouModel.disconnectTitle(row),
      isPresented: Binding(
        get: { model.confirmingDisconnect == row },
        set: { if !$0, model.confirmingDisconnect == row { model.confirmingDisconnect = nil } }),
      titleVisibility: .visible, presenting: row
    ) { row in
      Button(AddedYouModel.disconnect, role: .destructive) {
        Task { await model.confirmDisconnect(row) }
      }
    } message: { row in
      Text(AddedYouModel.disconnectMessage(row))
    }
  }
}

#Preview {
  let session = Session.stub(
    transport: StubTransport(routes: [
      "GET people/added-you": .json(
        #"{"data":[{"uuid":"01a0a51f-afe3-7363-a0bc-b0d634c35924","name":"Robin Diver","#
          + #""username":"robin","avatar_sha256":null}],"total_count":1,"has_more":false,"#
          + #""page":1,"items_per_page":50}"#)
    ]))
  let model = AddedYouModel(session: session)
  ScrollView {
    AddedYouSection(model: model)
      .padding()
  }
  .background(Color.pageBackground)
  .task { await model.refresh() }
  .environment(session)
}
