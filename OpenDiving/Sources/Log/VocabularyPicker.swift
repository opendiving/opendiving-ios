import OpenDivingKit
import SwiftUI

/// A pick-list field: *Not recorded* first, then the vocabulary in the web's order, and a stored
/// value outside it kept on offer so a save never drops it unasked.
struct VocabularyPicker: View {
  let title: String
  let values: [String]
  let label: (String) -> String
  let selection: String?
  var notRecorded = "Not recorded"
  var error: String?
  let onChange: (String?) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Picker(title, selection: Binding(get: { selection }, set: { onChange($0) })) {
        Text(notRecorded).tag(String?.none)
        ForEach(offered, id: \.self) { value in
          Text(label(value)).tag(String?.some(value))
        }
      }
      if let error { FieldMessage(error) }
    }
  }

  private var offered: [String] {
    guard let selection, !values.contains(selection) else { return values }
    return values + [selection]
  }
}

#Preview {
  Form {
    VocabularyPicker(
      title: "Water type", values: FormVocabulary.waterTypes, label: VocabularyLabels.waterType,
      selection: "salt"
    ) { _ in }
  }
}
