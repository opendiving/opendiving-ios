import OpenDivingKit
import SwiftUI

/// The dive time, set on a wheel of minutes and one of seconds. A form that holds none stays
/// empty until a wheel is turned, so opening the sheet never answers for the diver.
struct DiveTimeField: View {
  let title: String
  let text: String
  var error: String?
  let onChange: (String) -> Void

  @State private var picking = false

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      WheelRow(title: title, value: text.isEmpty ? "Not recorded" : text) { picking = true }
      if let error { FieldMessage(error) }
    }
    .sheet(isPresented: $picking) {
      WheelSheet(title: "Dive time", value: text.isEmpty ? "0:00" : text) {
        HStack(spacing: 0) {
          wheel("Minutes", unit: "min", 0...DiveDuration.maxMinutes, part: total / 60) {
            set(minutes: $0, seconds: total % 60)
          }
          wheel("Seconds", unit: "sec", 0...59, part: total % 60) {
            set(minutes: total / 60, seconds: $0)
          }
        }
      }
    }
  }

  private var total: Int { DiveDuration.seconds(fromForm: text) ?? 0 }

  private func set(minutes: Int, seconds: Int) {
    onChange(DiveDuration.formText(seconds: minutes * 60 + seconds))
  }

  private func wheel(
    _ label: String, unit: String, _ range: ClosedRange<Int>, part: Int,
    onChange: @escaping (Int) -> Void
  ) -> some View {
    HStack(spacing: 4) {
      Picker(label, selection: Binding(get: { part }, set: onChange)) {
        ForEach(range, id: \.self) { Text(String($0)).tag($0) }
      }
      .pickerStyle(.wheel)
      .labelsHidden()
      Text(unit).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .clipped()
  }
}

#Preview {
  Form {
    DiveTimeField(title: "Dive time *", text: "45:30") { _ in }
  }
}
