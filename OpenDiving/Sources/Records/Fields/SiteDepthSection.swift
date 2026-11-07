import OpenDivingKit
import SwiftUI

/// How deep a site is, in what water and how high.
struct SiteDepthSection: View {
  @Binding var values: DiveSiteFormValues
  let units: RecordEntryUnits
  @Binding var invalid: Set<String>
  let message: (String) -> String?

  var body: some View {
    Section {
      RecordMeasuredField(
        label: "Depth from", key: "depth_from", measure: .depth, units: units.units(.depth),
        example: 5, value: $values.depthFrom, invalid: $invalid,
        message: message("depth_from"), onToggle: { units.toggle(.depth) })
      RecordMeasuredField(
        label: "Depth to", key: "depth_to", measure: .depth, units: units.units(.depth),
        example: 30, value: $values.depthTo, invalid: $invalid,
        message: message("depth_to"), onToggle: { units.toggle(.depth) })
      Picker("Water type", selection: $values.waterType) {
        Text("Not recorded").tag(String?.none)
        ForEach(FormVocabulary.waterTypes, id: \.self) { type in
          Text(VocabularyLabels.waterType(type)).tag(Optional(type))
        }
      }
      RecordMeasuredField(
        label: "Altitude", key: "altitude", measure: .altitude,
        units: units.units(.altitude), example: 372, value: $values.altitudeMeters,
        invalid: $invalid,
        message: message("altitude"), onToggle: { units.toggle(.altitude) },
        allowsNegative: true)
    } header: {
      FormSectionHeader(title: "Depth & Water", icon: .waves)
    }
  }
}

#Preview {
  @Previewable @State var values = DiveSiteFormValues()
  @Previewable @State var invalid: Set<String> = []
  Form {
    SiteDepthSection(
      values: $values,
      units: RecordEntryUnits(session: Session.stub(transport: StubTransport(routes: [:]))),
      invalid: $invalid, message: { _ in nil })
  }
}
