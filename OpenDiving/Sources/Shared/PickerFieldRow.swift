import OpenDivingKit
import SwiftUI

/// A record a form names: the label above, the record or the prompt below, and a tap anywhere
/// opening its picker.
struct PickerFieldRow: View {
  let title: String
  let row: FormPickerRow?
  let prompt: String
  let action: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      FieldLabel(title)
      Button(action: action) {
        HStack {
          if let row {
            PickerRowLabel(row: row)
          } else {
            Text(prompt).foregroundStyle(.secondary)
            Spacer()
          }
          Image(systemName: "chevron.up.chevron.down")
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
  }
}

#Preview {
  Form {
    PickerFieldRow(title: "Trip", row: nil, prompt: "Select a trip...") {}
  }
}
