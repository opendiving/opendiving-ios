import OpenDivingKit
import SwiftUI

/// A site's entries in other registries, which can be taken off and never typed; no section for a
/// site with none.
struct SiteRegistriesSection: View {
  @Binding var entries: [ExternalIdWrite]

  var body: some View {
    if !entries.isEmpty {
      Section {
        ForEach(entries, id: \.self) { entry in
          Text("\(ExternalIdRegistry.label(entry.registry)) \(entry.identifier)")
            .swipeToDelete { entries.removeAll { $0 == entry } }
        }
      } header: {
        FormSectionHeader(title: "In Other Registries", icon: .globe)
      }
    }
  }
}

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
  @Previewable @State var values = DiveSiteFormValues(
    externalIds: [ExternalIdWrite(registry: "openstreetmap", identifier: "node/255316037")])
  Form {
    SiteRegistriesSection(entries: $values.externalIds)
    SiteEntryTypesSection(values: $values)
  }
}
