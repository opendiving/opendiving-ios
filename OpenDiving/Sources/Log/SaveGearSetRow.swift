import OpenDivingKit
import SwiftUI

/// *Save as set*, which keeps the dive's gear and weight as a set for the next dive.
struct SaveGearSetRow: View {
  let model: DiveFormModel

  @State private var saving = false

  var body: some View {
    Button("Save as set") { saving = true }
      .disabled(model.values.gearItems.isEmpty)
      .sheet(isPresented: $saving) {
        SaveGearSetSheet(items: model.values.gearItems, weight: model.values.weight) { _ in }
      }
  }
}

#Preview {
  Form {
    SaveGearSetRow(model: DiveFormModel(session: DivePreviewData.session, mode: .create))
  }
}
