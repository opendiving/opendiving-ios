import OpenDivingKit
import SwiftUI

/// The dive time, set on a wheel of minutes and one of seconds.
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
      DiveTimeSheet(text: text, onDone: onChange)
    }
  }
}

/// The two wheels. *Done* on a form that holds no time, with both still at zero, keeps it empty:
/// a dive of no length is not an answer anyone gave.
private struct DiveTimeSheet: View {
  let text: String
  let onDone: (String) -> Void

  @State private var minutes: Int
  @State private var seconds: Int

  init(text: String, onDone: @escaping (String) -> Void) {
    let total = DiveDuration.seconds(fromForm: text) ?? 0
    self.text = text
    self.onDone = onDone
    _minutes = State(initialValue: total / 60)
    _seconds = State(initialValue: total % 60)
  }

  var body: some View {
    let total = minutes * 60 + seconds
    let picked = DiveDuration.formText(seconds: total)
    WheelSheet(title: "Dive time", value: picked) {
      if !text.isEmpty || total > 0 { onDone(picked) }
    } wheels: {
      HStack(spacing: 0) {
        wheel("Minutes", unit: "min", 0...DiveDuration.maxMinutes, $minutes)
        wheel("Seconds", unit: "sec", 0...59, $seconds)
      }
    }
  }

  private func wheel(
    _ label: String, unit: String, _ range: ClosedRange<Int>, _ selection: Binding<Int>
  ) -> some View {
    HStack(spacing: 4) {
      Picker(label, selection: selection) {
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
