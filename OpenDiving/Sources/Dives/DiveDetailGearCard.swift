import OpenDivingKit
import SwiftUI

/// The gear the diver took — type, brand and name, marked when rented or archived — and
/// the weight they carried.
struct DiveDetailGearCard: View {
  let gear: DiveDetailContent.Gear

  var body: some View {
    SectionCard(title: "Gear", systemImage: "backpack") {
      if !gear.items.isEmpty {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
          GridRow {
            Text("Type")
            Text("Brand")
            Text("Name")
          }
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
          ForEach(Array(gear.items.enumerated()), id: \.offset) { _, item in
            Divider()
            GridRow {
              Text(item.type).foregroundStyle(.secondary)
              Text(item.brand)
              VStack(alignment: .leading, spacing: 4) {
                Text(item.name).fontWeight(.medium)
                if item.rented || item.archived {
                  HStack(spacing: 4) {
                    if item.rented { BadgeView("Rented") }
                    if item.archived { BadgeView("Archived", style: .outline) }
                  }
                }
              }
            }
          }
        }
        .font(.subheadline)
      }
      if let weight = gear.weight {
        InfoRow(label: "Weight") {
          Label(weight, systemImage: "scalemass")
            .fontWeight(.medium)
        }
      }
    }
  }
}

#Preview {
  ScrollView {
    if let gear = DivePreviewData.content.gear {
      DiveDetailGearCard(gear: gear)
        .padding()
    }
  }
  .background(Color(.systemGroupedBackground))
}
