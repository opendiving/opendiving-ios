import OpenDivingKit
import SwiftUI

/// A measured number: typed in the dimension's entry units on this phone, kept metric, with the
/// toggle beside its label. While the box has focus it shows what was typed; otherwise the
/// stored value in the entry units.
struct MeasuredField: View {
  let model: DiveFormModel
  let title: String
  let measure: Measure
  /// A metric example for the placeholder, as the web gives one.
  var example: Double?
  /// Metric bounds, for the sentence under a number outside them.
  var min: Double?
  var max: Double?
  let value: Double?
  var error: String?
  let onChange: (Double?) -> Void

  @State private var text = ""
  @FocusState private var focused: Bool

  var body: some View {
    let units = model.entryUnits(measure)
    VStack(alignment: .leading, spacing: 6) {
      FieldLabel(model.label(title, measure)) {
        EntryUnitToggle(measure: measure, current: units) { model.toggleEntryUnits(measure) }
      }
      TextField(example.map { model.placeholder($0, measure) } ?? "", text: $text)
        .keyboardType(keyboard)
        .focused($focused)
        .onChange(of: text) { _, typed in
          guard focused else { return }
          onChange(model.metric(fromEntry: typed, measure))
        }
      if let message = model.entryMessage(text, measure, min: min, max: max) ?? error {
        FieldMessage(message)
      }
    }
    .onAppear { text = model.entryText(value, measure) }
    .onChange(of: value) { _, _ in if !focused { text = model.entryText(value, measure) } }
    .onChange(of: units) { _, _ in text = model.entryText(value, measure) }
    .onChange(of: focused) { _, now in if !now { text = model.entryText(value, measure) } }
  }

  /// The decimal keypad has no minus sign, so a field that takes a negative gets the
  /// punctuation keyboard.
  private var keyboard: UIKeyboardType {
    if let min, min < 0 { return .numbersAndPunctuation }
    return measure == .visibility || measure == .altitude ? .numberPad : .decimalPad
  }
}

#Preview {
  let model = DiveFormModel(session: DivePreviewData.session, mode: .create)
  Form {
    MeasuredField(
      model: model, title: "Maximum depth", measure: .depth, example: 30.52, min: 0,
      value: 18.3
    ) { _ in }
  }
}
