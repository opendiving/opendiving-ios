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
      .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))
    SortableRows(
      items: model.binding(\.diveSites), identity: { $0 },
      title: { model.row($0, .diveSites).title },
      row: { index, ref in
        HStack {
          PickerRowLabel(row: model.row(ref, .diveSites))
          if sites.count > 1 { DragHandle() }
        }
        .listRowSeparator(index == 0 ? .hidden : .automatic, edges: .top)
      })
    Button(FormPicker.diveSites.placeholder(holdsSome: !sites.isEmpty)) { picking = true }
      .accentRow()
      .listRowSeparator(sites.isEmpty ? .hidden : .automatic, edges: .top)
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
