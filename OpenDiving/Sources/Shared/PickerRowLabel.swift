import OpenDivingKit
import SwiftUI

/// A picker row: the record's name, what tells it apart, and the mark of one not yet on the
/// server.
struct PickerRowLabel: View {
  let row: FormPickerRow
  var isSelected = false

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(row.title).foregroundStyle(Color.primary)
          if row.isPending { PendingMark() }
        }
        if let subtitle = row.subtitle {
          Text(subtitle).font(.subheadline).foregroundStyle(Color.secondary)
        }
      }
      Spacer()
      if isSelected {
        Image(systemName: "checkmark").foregroundStyle(Color.accentText)
      }
    }
  }
}

#Preview {
  Form {
    PickerRowLabel(row: FormPickerRow(ref: .local(UUID()), title: "Blue Hole", subtitle: "Dahab"))
  }
}
