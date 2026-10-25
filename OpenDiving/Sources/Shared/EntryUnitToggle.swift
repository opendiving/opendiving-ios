import OpenDivingKit
import SwiftUI

/// The toggle beside a measured field's label, `m | ft` with the one typed in bold, which flips
/// that dimension's entry for this phone.
struct EntryUnitToggle: View {
  let measure: Measure
  let current: UnitSystem
  let onToggle: () -> Void

  var body: some View {
    Button(action: onToggle) {
      HStack(spacing: 2) {
        part(.metric)
        Text("|").foregroundStyle(.tertiary)
        part(.imperial)
      }
      .font(.caption)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(.separator)))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      "\(measure.label(.metric)) | \(measure.label(.imperial)) — switch entry to "
        + measure.word(current == .metric ? .imperial : .metric))
  }

  private func part(_ units: UnitSystem) -> some View {
    Text(measure.label(units))
      .fontWeight(units == current ? .semibold : .regular)
      .foregroundStyle(units == current ? .primary : .secondary)
  }
}

#Preview {
  EntryUnitToggle(measure: .depth, current: .metric) {}
}
