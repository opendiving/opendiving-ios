import OpenDivingKit
import SwiftUI

/// The dive page's profile card: a switcher across the recordings that carry a profile when
/// there is more than one, the chart of the one chosen, and what its computer recorded.
struct DiveDetailProfileCard: View {
  let diveUUID: UUID
  let profile: DiveDetailContent.Profile

  /// By uuid rather than index, and falling back to the first, so a dive stepped to with
  /// other recordings never charts a stale choice.
  @State private var shownUUID: UUID?

  var body: some View {
    let shown = profile.recordings.first { $0.id == shownUUID } ?? profile.recordings[0]
    SectionCard(title: "Dive Profile", systemImage: "chart.xyaxis.line") {
      if profile.recordings.count > 1 {
        FlowLayout(spacing: 8, lineSpacing: 8) {
          ForEach(profile.recordings) { recording in
            switcherButton(recording, isShown: recording.id == shown.id)
          }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Which recording to chart")
      }
      DiveProfileChartView(
        diveUUID: diveUUID, recordingUUID: shown.id, cylinderLabels: profile.cylinderLabels)
      Text(shown.description)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private func switcherButton(
    _ recording: DiveDetailContent.Profile.ChartedRecording, isShown: Bool
  ) -> some View {
    let button = Button(recording.label) { shownUUID = recording.id }
      .controlSize(.small)
      .accessibilityAddTraits(isShown ? .isSelected : [])
    if isShown {
      button.buttonStyle(.borderedProminent)
    } else {
      button.buttonStyle(.bordered)
    }
  }
}

#Preview {
  ScrollView {
    if let profile = DivePreviewData.content.profile {
      DiveDetailProfileCard(diveUUID: DivePreviewData.diveUUID, profile: profile)
        .padding()
    }
  }
  .background(Color(.systemGroupedBackground))
}
