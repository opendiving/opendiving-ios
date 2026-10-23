import OpenDivingKit
import SwiftUI

/// The scrubber's readings at one instant, one row per shown line — a dash where it
/// recorded nothing in reach — grouped by the graph they come from, with the marker under
/// the finger below a rule.
struct ProfileReadoutCard: View {
  let elapsed: String
  let readouts: [ProfileReadout]
  let event: ProfileChartEvent?

  var body: some View {
    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 2) {
      GridRow {
        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
        Text(elapsed + " elapsed").font(.caption).foregroundStyle(.secondary)
      }
      ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
        if index > 0 { Divider().gridCellColumns(2) }
        ForEach(group) { readout in
          GridRow {
            Text(readout.sample?.text ?? "—")
              .fontWeight(.semibold)
              .monospacedDigit()
              .foregroundStyle(
                readout.sample == nil
                  ? AnyShapeStyle(.tertiary) : AnyShapeStyle(readout.channel.color)
              )
              .gridColumnAlignment(.trailing)
            Text(readout.label)
              .foregroundStyle(
                readout.sample == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
          }
        }
      }
      if let event {
        Divider().gridCellColumns(2)
        GridRow {
          Image(systemName: event.systemImage)
            .imageScale(.small)
            .foregroundStyle(event.color)
          Text(event.text)
            .fontWeight(.semibold)
            .foregroundStyle(event.color)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .font(.footnote)
    .padding(8)
    .frame(maxWidth: 320, alignment: .leading)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
  }

  /// Consecutive readings on the same graph, as one group each.
  private var groups: [[ProfileReadout]] {
    var groups: [[ProfileReadout]] = []
    for readout in readouts {
      if let last = groups.last?.last, last.panelIndex == readout.panelIndex {
        groups[groups.count - 1].append(readout)
      } else {
        groups.append([readout])
      }
    }
    return groups
  }
}

#Preview {
  let chart = ProfileChart.preview
  ProfileReadoutCard(
    elapsed: DiveProfileMath.formatElapsed(milliseconds: 600_000),
    readouts: chart.layout(hiding: []).readouts(at: 600_000),
    event: chart.events.first
  )
  .padding()
}
