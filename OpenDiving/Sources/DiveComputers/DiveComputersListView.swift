import OpenDivingKit
import SwiftUI

/// Settings' *Dive Computers*: the account's paired computers, each with what
/// the phone remembers of it, *Download all dives next time*, *Forget this dive computer*, and,
/// for a computer that logs instants, the zone its dives are written in.
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
          if record.family.logsInstants {
            zone(record)
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
    .forgetDiveComputerConfirmation(record: $forgetting) { model.forget($0) }
  }

  /// The zone the computer's dives are written in, the diver's where set and the watch's as
  /// last reported otherwise; the picker sets the diver's, which wins over the watch's.
  @ViewBuilder private func zone(_ record: DiveComputerRecord) -> some View {
    TimeZonePicker(
      title: "Time zone",
      selection: Binding(
        get: { record.zone ?? .current },
        set: { model.setDiverZone($0, for: record) }))
    if record.diverZone != nil, record.watchZone != nil {
      Button("Use the watch's time zone") { model.setDiverZone(nil, for: record) }
    }
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  NavigationStack {
    DiveComputersListView(model: DiveComputersListModel(session: session))
  }
}
