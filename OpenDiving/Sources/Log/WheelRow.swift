import SwiftUI

/// A row showing a value set on wheels, laid out as a select is; tapping it anywhere opens them.
struct WheelRow: View {
  let title: String
  let value: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack {
        Text(title)
        Spacer()
        Text(value).foregroundStyle(.secondary)
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
    WheelRow(title: "Dive time *", value: "45:30") {}
  }
}
