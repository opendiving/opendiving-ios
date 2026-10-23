import OpenDivingKit
import SwiftUI

/// The dive's cylinders, one card each — the gas and its role, what was recorded of it, its
/// pressures and its MOD — then the dive-wide MOD warning.
struct DiveDetailTanksCard: View {
  let tanks: DiveDetailContent.Tanks

  var body: some View {
    SectionCard(title: "Tanks", systemImage: "cylinder.split.1x2") {
      VStack(spacing: 8) {
        ForEach(Array(tanks.tanks.enumerated()), id: \.offset) { _, tank in
          TankView(tank: tank)
        }
      }
      if let warning = tanks.warning {
        Label(warning, systemImage: "exclamationmark.triangle")
          .font(.subheadline)
          .foregroundStyle(.orange)
      }
    }
  }
}

private struct TankView: View {
  let tank: DiveDetailContent.Tanks.Tank

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Text(tank.number)
          .font(.body.weight(.medium))
        Text(tank.gas ?? "Gas not recorded")
          .font(.body.weight(.medium))
          .foregroundStyle(tank.gas == nil ? Color.secondary : Color.primary)
        if let role = tank.role {
          BadgeView(role, style: .teal)
        }
      }
      .accessibilityElement(children: .combine)
      FactsLine(facts: tank.facts.map { Fact(text: $0) })
      HStack(alignment: .top, spacing: 16) {
        figure("Start", value: tank.start)
        figure("End", value: tank.end)
        VStack(alignment: .leading, spacing: 0) {
          HStack(spacing: 4) {
            Text("MOD")
            if let condition = tank.modCondition {
              Text(condition).foregroundStyle(.secondary)
            }
          }
          .font(.caption)
          HStack(spacing: 4) {
            if tank.warned {
              Image(systemName: "exclamationmark.triangle")
                .accessibilityLabel("Past this gas's MOD")
            }
            Text(tank.mod ?? "-")
          }
          .font(.body.weight(.bold))
          .foregroundStyle(tank.warned ? Color.orange : tank.mod == nil ? .secondary : .primary)
        }
        .accessibilityElement(children: .combine)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(.separator)))
  }

  private func figure(_ label: String, value: String?) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(label).font(.caption)
      Text(value ?? "-")
        .font(.body.weight(.bold))
        .foregroundStyle(value == nil ? Color.secondary : Color.primary)
    }
    .accessibilityElement(children: .combine)
  }
}

#Preview {
  ScrollView {
    if let tanks = DivePreviewData.content.tanks {
      DiveDetailTanksCard(tanks: tanks)
        .padding()
    }
  }
  .background(Color(.systemGroupedBackground))
}
