import OpenDivingKit
import SwiftUI

/// What every proposal ends on: an optional word for the reviewer, then the proposer's own tick
/// on the words the API stores. The deed is a row of its own, so following it ticks nothing.
struct CommonsAttestationSection: View {
  let attestation: String
  @Binding var ticked: Bool
  @Binding var message: String

  var body: some View {
    Section {
      TextField(
        "A word for the reviewer", text: $message,
        prompt: Text("Optional. Only the reviewer reads this."), axis: .vertical
      )
      .lineLimit(2...6)
    } header: {
      Text("A Word for the Reviewer")
    }
    Section {
      Toggle(isOn: $ticked) {
        Text(attestation)
          .font(.subheadline)
      }
      .tint(.brandTeal)
      if let deed = URL(string: CommonsAttestations.deed) {
        Link("Read the CC0 1.0 deed", destination: deed)
          .accentRow()
      }
    }
  }
}

#Preview {
  @Previewable @State var ticked = false
  @Previewable @State var message = ""
  Form {
    CommonsAttestationSection(
      attestation: CommonsAttestations.newSite, ticked: $ticked, message: $message)
  }
}
