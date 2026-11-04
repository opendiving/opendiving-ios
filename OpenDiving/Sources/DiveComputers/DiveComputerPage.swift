import OpenDivingKit
import SwiftUI

/// One paired computer, opened from *Paired Computers*: what it has reported of itself, and
/// forgetting it.
struct DiveComputerPage: View {
  let record: DiveComputerRecord
  let forget: () -> Void
  @State private var forgetting: DiveComputerRecord?

  private var content: DiveComputerPageContent { DiveComputerPageContent(record) }

  var body: some View {
    Form {
      Section {
        ForEach(content.facts) { fact in
          LabeledContent(fact.label, value: fact.value)
        }
      }
      Section {
        Button(DiveComputerText.forget, role: .destructive) { forgetting = record }
          .forgetDiveComputerConfirmation(record: $forgetting) { _ in forget() }
      }
    }
    .navigationTitle(content.title)
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  NavigationStack {
    DiveComputerPage(
      record: DiveComputerRecord(
        identity: DiveComputerIdentity(
          family: .shearwaterPetrel, vendor: "Shearwater", product: "Perdix 3",
          serial: "D9772626", firmware: "93", hardware: "0B0B", familyNumber: 0, modelNumber: 14),
        lastDownloaded: Date()),
      forget: {})
  }
}
