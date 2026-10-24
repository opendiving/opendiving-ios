import OpenDivingKit
import SwiftUI

/// A plain number in the same units on both systems — a percentage, a volume — read with
/// either decimal separator.
struct DecimalField: View {
  let title: String
  var placeholder = ""
  let value: Double?
  var isReadOnly = false
  var error: String?
  let onChange: (Double?) -> Void

  @State private var text = ""
  @FocusState private var focused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      FieldLabel(title)
      TextField(placeholder, text: $text)
        .keyboardType(.decimalPad)
        .focused($focused)
        .disabled(isReadOnly)
        .foregroundStyle(isReadOnly ? .secondary : .primary)
        .onChange(of: text) { _, typed in
          guard focused else { return }
          onChange(DecimalEntry.parse(typed))
        }
      if let message = DecimalEntry.message(text) ?? error {
        FieldMessage(message)
      }
    }
    .onAppear { text = Self.text(value) }
    .onChange(of: value) { _, _ in if !focused { text = Self.text(value) } }
    .onChange(of: focused) { _, now in if !now { text = Self.text(value) } }
  }

  static func text(_ value: Double?) -> String {
    value.map(NumberText.plain) ?? ""
  }
}

#Preview {
  Form {
    DecimalField(title: "O₂ (%)", value: 32) { _ in }
  }
}
