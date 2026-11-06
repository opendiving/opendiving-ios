import SwiftUI

/// A form's Location: the place's name, or the prompt, which opens the location picker. The name
/// is found there and never typed.
struct LocationField: View {
  let name: String?
  var note: String?
  var message: String?
  let action: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      FieldLabel("Location")
      Button(action: action) {
        HStack {
          Text(name ?? "Search for a place...")
            .foregroundStyle(name == nil ? .secondary : .primary)
          Spacer()
          Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      if let note {
        Text(note).font(.caption).foregroundStyle(.secondary)
      }
      FieldMessage(message)
    }
  }
}

#Preview {
  Form {
    LocationField(name: nil) {}
    LocationField(name: "Dahab, South Sinai, Egypt", note: "Not on the map") {}
  }
}
