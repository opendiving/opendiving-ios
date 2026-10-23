import OpenDivingKit
import SwiftUI

/// One recording's profile chart, inside the dive page's profile card. Loads keyed on the
/// recording, so the card's switcher redraws it in place.
struct DiveProfileChartView: View {
  let diveUUID: UUID
  let recordingUUID: UUID
  /// Each of the dive's mixtures' `gas_number`, in the order the Tanks card lists them,
  /// so a pressure series or a gas switch is named `tank N` where one cylinder carries
  /// the label.
  let cylinderLabels: [Int?]

  @Environment(Session.self) private var session
  @State private var load = ProfileLoad.loading
  @State private var attempt = 0
  // Held here rather than in the plot, so a channel switched off stays off when the card
  // switches to another recording.
  @State private var hidden: Set<ProfileChannel> = []
  @State private var markersHidden = false

  var body: some View {
    content
      .task(id: LoadKey(dive: diveUUID, recording: recordingUUID, attempt: attempt)) {
        load = .loading
        let result = await ProfileLoad.fetch(
          dive: diveUUID, recording: recordingUUID, from: session.client)
        guard !Task.isCancelled else { return }
        load = result
      }
  }

  @ViewBuilder private var content: some View {
    switch load {
    case .loading:
      ProgressView()
        .frame(maxWidth: .infinity, minHeight: 200)
    case .loaded(let profile):
      let chart = ProfileChart(profile: profile, units: session.units, cylinders: cylinderLabels)
      if chart.hasSamples {
        ProfileChartPlot(chart: chart, hidden: $hidden, markersHidden: $markersHidden)
      } else {
        note("This recording's file recorded no samples to plot.")
      }
    case .missing(let message):
      note(message)
    case .failed(let message):
      VStack(alignment: .leading, spacing: 8) {
        note(message)
        Button("Try again") { attempt += 1 }
          .buttonStyle(.bordered)
          .controlSize(.small)
      }
    }
  }

  private func note(_ text: String) -> some View {
    Text(text)
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private struct LoadKey: Hashable {
    let dive: UUID
    let recording: UUID
    let attempt: Int
  }
}

#Preview {
  let dive = UUID()
  let recording = UUID()
  let route =
    "GET dive/\(dive.uuidString.lowercased())/recording/\(recording.uuidString.lowercased())/profile"
  DiveProfileChartView(diveUUID: dive, recordingUUID: recording, cylinderLabels: [1, 2])
    .padding()
    .environment(
      Session.stub(transport: StubTransport(routes: [route: .json(ProfileChartPlot.previewJSON)])))
}
