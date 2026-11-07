import OpenDivingKit
import SwiftUI

/// A measured number as the web's unit input takes it, on one line as the dive form draws it:
/// typed in `units`, kept metric, with the unit after the box — or, where the web offers one, the
/// toggle that flips it. Text that is not a number keeps its sentence under the box and its key in
/// `invalid`, which holds the save back.
struct RecordMeasuredField: View {
  let label: String
  let key: String
  let measure: Measure
  let units: UnitSystem
  /// The example the placeholder shows, metric.
  var example: Double?
  @Binding var value: Double?
  @Binding var invalid: Set<String>
  var message: String?
  var onToggle: (() -> Void)?
  /// The decimal keypad has no minus key, so a box that takes a negative — an altitude below
  /// sea level — gets the punctuation keyboard.
  var allowsNegative = false

  @State private var text = ""
  @State private var entryMessage: String?
  @FocusState private var focused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      InlineField(label, focus: $focused) {
        TextField(label, text: $text, prompt: prompt)
          .keyboardType(allowsNegative ? .numbersAndPunctuation : .decimalPad)
          .labelsHidden()
          .focused($focused)
      } trailing: {
        if let onToggle {
          EntryUnitToggle(measure: measure, current: units, onToggle: onToggle)
        } else {
          Text(measure.label(units)).foregroundStyle(.secondary)
        }
      }
      FieldMessage(entryMessage ?? message)
    }
    .onAppear { text = RecordEntryUnits.text(value, measure, units) }
    .onChange(of: units) { text = RecordEntryUnits.text(value, measure, units) }
    // A value set from outside the box, a preset's rating, shows in it; one the box just
    // committed already reads as typed.
    .onChange(of: value) { _, new in
      if RecordEntryUnits.value(text, measure, units) != .success(new) {
        text = RecordEntryUnits.filledText(new, measure, units)
      }
    }
    .onChange(of: text) { commit() }
  }

  private var prompt: Text? {
    example.map { Text("e.g. \(NumberText.plain(measure.toDisplay($0, units).rounded()))") }
  }

  private func commit() {
    switch RecordEntryUnits.value(text, measure, units) {
    case .success(let metric):
      entryMessage = nil
      invalid.remove(key)
      // Re-rendering the same number in other units would rewrite what is being typed.
      if metric != value { value = metric }
    case .failure(let failure):
      entryMessage = failure.message
      invalid.insert(key)
    }
  }
}

#Preview {
  @Previewable @State var depth: Double? = 12
  @Previewable @State var invalid: Set<String> = []
  Form {
    RecordMeasuredField(
      label: "Depth from", key: "depth_from", measure: .depth, units: .imperial, example: 5,
      value: $depth, invalid: $invalid, onToggle: {})
  }
}
