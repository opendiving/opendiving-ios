import OpenDivingKit
import SwiftUI

/// Settings' *Dive Computers*: the account's paired computers, each with what
/// the phone remembers of it, *Download all dives next time* and *Forget this dive computer*.
struct DiveComputersListView: View {
  let model: DiveComputersListModel

  @State private var forgetting: DiveComputerRecord?

  var body: some View {
    List {
      if model.computers.isEmpty {
        Text(DiveComputerText.emptyList).foregroundStyle(.secondary)
      }
      ForEach(model.computers) { record in
        Section {
          VStack(alignment: .leading, spacing: 2) {
            Text(record.title)
            if let subtitle = model.subtitle(record) {
              Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
          }
          if record.downloadAllNextTime {
            Label(DiveComputerText.downloadAllNextTime, systemImage: "checkmark")
              .foregroundStyle(.secondary)
          } else {
            Button(DiveComputerText.downloadAllNextTime) { model.downloadAllNextTime(record) }
          }
          Button(DiveComputerText.forget, role: .destructive) { forgetting = record }
        }
      }
      if let error = model.error {
        Text(error).foregroundStyle(.red)
      }
    }
    .navigationTitle(DiveComputerText.settingsRow)
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { model.reload() }
    .confirmationDialog(
      forgetting.map(DiveComputerText.forgetTitle) ?? DiveComputerText.forget,
      isPresented: Binding(get: { forgetting != nil }, set: { if !$0 { forgetting = nil } }),
      titleVisibility: .visible, presenting: forgetting
    ) { record in
      Button("Forget", role: .destructive) { model.forget(record) }
    } message: { _ in
      Text(DiveComputerText.forgetMessage)
    }
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  NavigationStack {
    DiveComputersListView(model: DiveComputersListModel(session: session))
  }
}
