import SwiftUI

/// A short sheet of wheels: what they set and its value so far, the wheels, and *Done*. Each turn
/// lands in the form as it happens, so *Done* and a swipe down both only close the sheet.
struct WheelSheet<Wheels: View>: View {
  let title: String
  let value: String
  @ViewBuilder let wheels: () -> Wheels

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 16) {
      HStack {
        Text(title).font(.headline)
        Spacer()
        Text(value).foregroundStyle(Color.brandTeal)
      }
      wheels()
      Button {
        dismiss()
      } label: {
        Text("Done")
          .bold()
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .tint(.brandTeal)
    }
    .padding()
    .presentationDetents([.height(400)])
    .presentationDragIndicator(.visible)
  }
}

#Preview {
  Text("Form")
    .sheet(isPresented: .constant(true)) {
      WheelSheet(title: "Start time", value: "Nov 4, 2026, 12:15") {
        DatePicker("Date", selection: .constant(.now)).datePickerStyle(.wheel).labelsHidden()
      }
    }
}
