import OpenDivingKit
import SwiftUI

/// A percentage of a gas, set on a whole-number wheel and a tenths wheel.
struct PercentField: View {
  let title: String
  let value: Double?
  var error: String?
  let onChange: (Double?) -> Void

  @State private var picking = false

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      SelectRow(title: title, value: Self.text(value)) { picking = true }
      if let error { FieldMessage(error) }
    }
    .sheet(isPresented: $picking) {
      PercentSheet(title: title, value: value, onDone: onChange)
    }
  }

  fileprivate static func text(_ percent: Double?) -> String {
    percent.map { "\(NumberText.plain($0)) %" } ?? "Not recorded"
  }
}

/// The wheels. *Done* leaves a value with more than a tenth alone unless a wheel was turned.
private struct PercentSheet: View {
  let title: String
  let value: Double?
  let onDone: (Double?) -> Void

  @State private var wheels: PercentWheels

  init(title: String, value: Double?, onDone: @escaping (Double?) -> Void) {
    self.title = title
    self.value = value
    self.onDone = onDone
    _wheels = State(initialValue: PercentWheels(value))
  }

  var body: some View {
    WheelSheet(title: title, value: PercentField.text(wheels.percent)) {
      if wheels != PercentWheels(value) { onDone(wheels.percent) }
    } wheels: {
      HStack(spacing: 0) {
        Picker("Percent", selection: $wheels.whole) {
          Text("Not recorded").tag(Int?.none)
          ForEach(PercentWheels.wholes, id: \.self) { Text(String($0)).tag(Int?.some($0)) }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .frame(maxWidth: .infinity)
        .clipped()
        Text(".").foregroundStyle(.secondary)
        Picker("Tenths", selection: $wheels.tenth) {
          ForEach(PercentWheels.tenths, id: \.self) { Text(String($0)).tag($0) }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .disabled(!wheels.takesTenths)
        .frame(maxWidth: .infinity)
        .clipped()
        Text("%").foregroundStyle(.secondary)
      }
    }
  }
}

#Preview {
  Form {
    PercentField(title: "O₂", value: 32.5) { _ in }
  }
}
