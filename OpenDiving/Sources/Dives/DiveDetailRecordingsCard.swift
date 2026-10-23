import OpenDivingKit
import SwiftUI

/// What recorded the dive and what the account still holds from each computer: the device,
/// what it was set to and reported, its own start where that differs, and its files.
struct DiveDetailRecordingsCard: View {
  let recordings: [DiveDetailContent.Recording]

  var body: some View {
    SectionCard(title: "Recordings", systemImage: "applewatch") {
      VStack(alignment: .leading, spacing: 20) {
        ForEach(recordings) { recording in
          RecordingView(recording: recording)
        }
      }
    }
  }
}

private struct RecordingView: View {
  let recording: DiveDetailContent.Recording

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      VStack(alignment: .leading, spacing: 2) {
        Text(recording.device)
          .font(.subheadline.weight(.medium))
        if let name = recording.name {
          Text(name).font(.caption).foregroundStyle(.secondary)
        }
        ForEach(
          [recording.settings, recording.readouts, recording.started].compactMap { $0 }, id: \.self
        ) { line in
          Text(line).font(.subheadline).foregroundStyle(.secondary)
        }
        if let firmware = recording.firmware {
          Text(firmware).font(.caption).foregroundStyle(.secondary)
        }
      }
      if let noFileKept = recording.noFileKept {
        Text(noFileKept).font(.subheadline).foregroundStyle(.secondary)
      } else {
        ForEach(recording.files) { file in
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "paperclip")
              .foregroundStyle(.secondary)
              .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
              Text(file.name).font(.subheadline.weight(.medium))
              Text(file.detail).font(.caption).foregroundStyle(.secondary)
            }
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(.separator)))
          .accessibilityElement(children: .combine)
        }
      }
    }
  }
}

#Preview {
  ScrollView {
    DiveDetailRecordingsCard(recordings: DivePreviewData.content.recordings)
      .padding()
  }
  .background(Color(.systemGroupedBackground))
}
