import SwiftUI

/// A row laid out as a select is, its label on the left and its value on the right, cut short if
/// it does not fit. Tapping it anywhere opens what sets the value.
struct SelectRow: View {
  let title: String
  let value: String
  var isPending = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack {
        Text(title)
          .layoutPriority(1)
        Spacer()
        Text(value)
          .foregroundStyle(.secondary)
          .lineLimit(1)
        if isPending { PendingMark() }
        Image(systemName: "chevron.up.chevron.down")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  Form {
    SelectRow(title: "Dive time *", value: "45:30") {}
  }
}
