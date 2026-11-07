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

#Preview {
  @Previewable @State var entries = [
    ExternalIdWrite(registry: "openstreetmap", identifier: "node/255316037")
  ]
  Form {
    SiteRegistriesSection(entries: $entries)
  }
}
