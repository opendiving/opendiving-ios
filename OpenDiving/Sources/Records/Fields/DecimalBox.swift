import OpenDivingKit
import SwiftUI

/// A plain number box, a cylinder's litres: either decimal separator, nil when empty, and the
/// sentence and `invalid` key for text that is not a number.
struct DecimalBox: View {
  let label: String
  let key: String
  var placeholder: String?
  @Binding var value: Double?
  @Binding var invalid: Set<String>
  var message: String?

  @State private var text = ""
  @State private var entryMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label).font(.subheadline.weight(.medium))
      TextField(label, text: $text, prompt: placeholder.map(Text.init))
        .keyboardType(.decimalPad)
        .labelsHidden()
      FieldMessage(text: entryMessage ?? message)
    }
    .onAppear { text = value.map(NumberText.plain) ?? "" }
    .onChange(of: value) { _, new in
      if new != DecimalEntry.parse(text) { text = new.map(NumberText.plain) ?? "" }
    }
    .onChange(of: text) { commit() }
  }

  private func commit() {
    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      entryMessage = nil
      invalid.remove(key)
      value = nil
    } else if let number = DecimalEntry.parse(text) {
      entryMessage = nil
      invalid.remove(key)
      if number != value { value = number }
    } else {
      entryMessage = DecimalEntry.message(text)
      invalid.insert(key)
    }
  }
}

#Preview {
  @Previewable @State var volume: Double? = 11.1
  @Previewable @State var invalid: Set<String> = []
  Form {
    DecimalBox(
      label: "Volume (L)", key: "volume", placeholder: "e.g. 11.1", value: $volume,
      invalid: $invalid)
  }
}
