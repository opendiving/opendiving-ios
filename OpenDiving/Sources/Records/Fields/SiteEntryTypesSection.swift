import OpenDivingKit
import SwiftUI

/// How divers get in, ticked in the order chosen.
struct SiteEntryTypesSection: View {
  @Binding var values: DiveSiteFormValues

  var body: some View {
    Section {
      ForEach(FormVocabulary.entryTypes, id: \.self) { entry in
        Toggle(
          VocabularyLabels.entryType(entry),
          isOn: Binding(
            get: { values.entryTypes.contains(entry) },
            set: { values.setEntryType(entry, $0) })
        )
        .tint(.brandTeal)
      }
    } header: {
      FormSectionHeader(title: "Entry Types", icon: .wavesArrowDown)
    }
  }
}

#Preview {
  @Previewable @State var values = DiveSiteFormValues()
  Form {
    SiteEntryTypesSection(values: $values)
  }
}
