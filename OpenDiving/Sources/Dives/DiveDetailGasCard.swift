import OpenDivingKit
import SwiftUI

/// The API's gas-consumption figures: three whole-dive figures, or a row per cylinder with
/// a total, or the sentence for a dive the API could not work them out for.
struct DiveDetailGasCard: View {
  let gas: DiveDetailContent.GasConsumption

  var body: some View {
    SectionCard(title: "Gas Consumption", systemImage: "waveform.path.ecg") {
      switch gas {
      case .unavailable(let reason):
        note(reason, font: .subheadline)
      case .figures(let figures, let explanation):
        FiguresRow(figures: figures)
        if let explanation { note(explanation) }
      case .table(let rows, let total, let explanation, let coverage):
        ScrollView(.horizontal) {
          Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
              Text("#").accessibilityLabel("Tank")
              Text("Gas")
              Text("Time")
              Text("Avg depth")
              Text("Used")
              Text("RMV")
              Text("SAC")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
              Divider()
              GasRowView(row: row)
            }
            if let total {
              Divider()
              GasRowView(row: total)
                .fontWeight(.medium)
            }
          }
          .font(.subheadline)
          .fixedSize()
        }
        note(explanation)
        if let coverage { note(coverage) }
      }
    }
  }

  private func note(_ text: String, font: Font = .caption) -> some View {
    Text(text)
      .font(font)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct GasRowView: View {
  let row: DiveDetailContent.GasRow

  var body: some View {
    GridRow {
      Text(row.label).foregroundStyle(.secondary)
      HStack(spacing: 4) {
        if let gas = row.gas {
          BadgeView(gas)
        } else {
          Text("-").foregroundStyle(.secondary)
        }
        if let role = row.role {
          BadgeView(role, style: .teal)
        }
      }
      if let cells = row.cells {
        ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
          Text(cell).foregroundStyle(cell == "-" ? Color.secondary : Color.primary)
        }
      } else {
        Text(row.emptyText ?? "")
          .foregroundStyle(.secondary)
          .gridCellColumns(5)
      }
    }
    .lineLimit(1)
  }
}

#Preview {
  ScrollView {
    VStack(spacing: 12) {
      if let gas = DivePreviewData.content.gasConsumption {
        DiveDetailGasCard(gas: gas)
      }
      DiveDetailGasCard(gas: .unavailable(DiveDetailContent.gasUseUnavailable))
    }
    .padding()
  }
  .background(Color(.systemGroupedBackground))
}
