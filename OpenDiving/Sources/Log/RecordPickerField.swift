import OpenDivingKit
import SwiftUI

/// A single record the dive names — its course, trip or dive centre, a tank's cylinder — shown by
/// name, or the picker's prompt, and picked in a sheet.
struct RecordPickerField: View {
  let model: DiveFormModel
  let title: String
  let picker: FormPicker
  var tank: Int?
  let value: RecordRef?
  let onChange: (RecordRef?) -> Void

  @State private var picking = false

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      FieldLabel(title)
      Button {
        picking = true
      } label: {
        HStack {
          if let value {
            PickerRowLabel(row: model.row(value, picker))
          } else {
            Text(picker.placeholder(holdsSome: false)).foregroundStyle(.secondary)
            Spacer()
          }
          Image(systemName: "chevron.up.chevron.down")
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
    .sheet(isPresented: $picking) {
      RecordPickerSheet(model: model, picker: picker, tank: tank, current: value, onPick: onChange)
    }
  }
}

#Preview {
  Form {
    RecordPickerField(
      model: DiveFormModel(session: DivePreviewData.session, mode: .create), title: "Trip",
      picker: .trip, value: nil
    ) { _ in }
  }
}
