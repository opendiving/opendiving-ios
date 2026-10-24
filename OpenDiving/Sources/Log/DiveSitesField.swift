import OpenDivingKit
import SwiftUI

/// The dive's sites in the order visited — the first is the primary — each movable and
/// removable, and the picker that adds the next.
struct DiveSitesField: View {
  let model: DiveFormModel

  @State private var picking = false

  var body: some View {
    let sites = model.values.diveSites
    VStack(alignment: .leading, spacing: 6) {
      FieldLabel(DiveFormField.diveSites.label)
      ForEach(Array(sites.enumerated()), id: \.element) { index, ref in
        HStack {
          PickerRowLabel(row: model.row(ref, .diveSites))
          if sites.count > 1 {
            Button {
              model.moveSite(ref, by: -1)
            } label: {
              Image(systemName: "arrow.up")
            }
            .buttonStyle(.borderless)
            .disabled(index == 0)
            .accessibilityLabel("Move \(model.row(ref, .diveSites).title) up")
          }
          Button {
            model.removeSite(ref)
          } label: {
            Image(systemName: "xmark")
          }
          .buttonStyle(.borderless)
          .accessibilityLabel("Remove \(model.row(ref, .diveSites).title)")
        }
      }
      Button(FormPicker.diveSites.placeholder(holdsSome: !sites.isEmpty)) { picking = true }
        .buttonStyle(.borderless)
    }
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
