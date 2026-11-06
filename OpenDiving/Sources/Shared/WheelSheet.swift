import SwiftUI

/// A short sheet of wheels: what they set and the value on them, a note on what bounds them, the
/// wheels, and *Done*, the one way a turn reaches the form. Swiping the sheet down leaves the form
/// as it was.
struct WheelSheet<Wheels: View>: View {
  let title: String
  let value: String
  var note: String?
  let onDone: () -> Void
  @ViewBuilder let wheels: () -> Wheels

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text(title).font(.headline)
          Spacer()
          Text(value).foregroundStyle(Color.accentText)
        }
        if let note {
          Text(note).font(.footnote).foregroundStyle(.secondary)
        }
      }
      wheels()
      Button {
        onDone()
        dismiss()
      } label: {
        Text("Done")
          .bold()
          .frame(maxWidth: .infinity)
      }
      .brandProminentButton()
      .controlSize(.large)
    }
    .padding()
    .presentationDetents([.height(400)])
    .presentationDragIndicator(.visible)
  }
}

#Preview {
  Text("Form")
    .sheet(isPresented: .constant(true)) {
      WheelSheet(title: "Start time", value: "Nov 4, 2026, 12:15", onDone: {}) {
        DatePicker("Date", selection: .constant(.now)).datePickerStyle(.wheel).labelsHidden()
      }
    }
}
