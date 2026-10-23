import OpenDivingKit
import SwiftUI

/// The primary recording's oxygen exposure and surface pressure, as its computer stored
/// them. A CNS end at the single-dive limit is emphasised, and said for VoiceOver.
struct DiveDetailExposureCard: View {
  let exposure: DiveDetailContent.Exposure

  var body: some View {
    SectionCard(title: "Exposure & Pressure", systemImage: "gauge.with.needle") {
      FlowLayout(spacing: 16, lineSpacing: 8) {
        ForEach(Array(exposure.readings.enumerated()), id: \.offset) { _, reading in
          VStack(alignment: .leading, spacing: 0) {
            Text(reading.label).font(.caption)
            HStack(spacing: 0) {
              Text(reading.start + " → ").foregroundStyle(.secondary)
              Text(reading.end)
                .fontWeight(.bold)
                .foregroundStyle(reading.alert == nil ? Color.primary : Color.orange)
            }
          }
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(
            "\(reading.label) \(reading.start) to \(reading.end)"
              + (reading.alert.map { ", " + $0 } ?? ""))
        }
        if let pressure = exposure.surfacePressure {
          VStack(alignment: .leading, spacing: 0) {
            Text("Surface pressure").font(.caption)
            Text(pressure).font(.body.weight(.bold))
          }
          .accessibilityElement(children: .combine)
        }
      }
    }
  }
}

#Preview {
  ScrollView {
    if let exposure = DivePreviewData.content.exposure {
      DiveDetailExposureCard(exposure: exposure)
        .padding()
    }
  }
  .background(Color(.systemGroupedBackground))
}
