import OpenDivingKit
import SwiftUI

/// The dive's sites in the order visited — the first is the primary — each a row of the form, so
/// it drags to a new place and swipes away, and the picker that adds the next.
struct DiveSitesField: View {
  let model: DiveFormModel

  @State private var picking = false

  var body: some View {
    let sites = model.values.diveSites
    FieldLabel(DiveFormField.diveSites.label)
      .listRowSeparator(.hidden, edges: .bottom)
    ForEach(Array(sites.enumerated()), id: \.element) { index, ref in
      let row = model.row(ref, .diveSites)
      HStack {
        PickerRowLabel(row: row)
        if sites.count > 1 {
          Image(systemName: "line.3.horizontal")
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
        }
      }
      .accessibilityActions {
        if index > 0 {
          Button("Move \(row.title) up") { model.moveSite(ref, by: -1) }
        }
        if index < sites.count - 1 {
          Button("Move \(row.title) down") { model.moveSite(ref, by: 1) }
        }
      }
    }
    .onMove { from, to in model.change { $0.diveSites.move(fromOffsets: from, toOffset: to) } }
    .onDelete { offsets in offsets.map { sites[$0] }.forEach(model.removeSite) }
    Button(FormPicker.diveSites.placeholder(holdsSome: !sites.isEmpty)) {
      UIApplication.endTyping()
      picking = true
    }
    .buttonStyle(.borderless)
    .sheet(isPresented: $picking) {
      RecordPickerSheet(model: model, picker: .diveSites) { ref in
        if let ref { model.addSite(ref) }
      }
    }
  }
}

#Preview {
  Form {
    DiveSitesField(model: DiveFormModel(session: DivePreviewData.session, mode: .create))
  }
}
