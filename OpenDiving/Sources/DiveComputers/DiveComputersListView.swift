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
              .accentRow()
          }
          Button(DiveComputerText.forget, role: .destructive) { forgetting = record }
            .foregroundStyle(Color.danger)
        }
      }
      if let error = model.error {
        Text(error).foregroundStyle(Color.danger)
      }
    }
    .navigationTitle(DiveComputerText.settingsRow)
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { model.reload() }
    .forgetDiveComputerConfirmation(record: $forgetting) { model.forget($0) }
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  NavigationStack {
    DiveComputersListView(model: DiveComputersListModel(session: session))
  }
}
