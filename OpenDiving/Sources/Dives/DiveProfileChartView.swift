import OpenDivingKit
import SwiftUI

/// One recording's profile chart, inside the dive page's profile card. Placeholder.
struct DiveProfileChartView: View {
  let diveUUID: UUID
  let recordingUUID: UUID
  /// Each of the dive's mixtures' `gas_number`, in the order the Tanks card lists them,
  /// so a pressure series or a gas switch is named `tank N` where one cylinder carries
  /// the label.
  let cylinderLabels: [Int?]

  var body: some View {
    EmptyOrErrorView(
      status: .empty(
        systemImage: "chart.xyaxis.line", title: "Profile", message: "Not built yet.")
    )
    .frame(minHeight: 200)
  }
}

#Preview {
  DiveProfileChartView(diveUUID: UUID(), recordingUUID: UUID(), cylinderLabels: [1, nil])
}
