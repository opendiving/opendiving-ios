import OpenDivingKit
import SwiftUI

/// A single record the dive names — its course, trip or dive centre, a tank's cylinder — shown by
/// name, or the picker's prompt, and picked in a sheet.
struct RecordPickerField: View {
  let model: DiveFormModel
  let title: String
  let picker: FormPicker
  var tank: Int?
  /// On one line, as a select is, for a value short enough to sit beside its label.
  var isInline = false
  let value: RecordRef?
  let onChange: (RecordRef?) -> Void

  @State private var picking = false

  var body: some View {
    Group {
      if isInline {
        SelectRow(
          title: title, value: row?.title ?? prompt, isPending: row?.isPending ?? false
        ) { picking = true }
      } else {
        PickerFieldRow(title: title, row: row, prompt: prompt) { picking = true }
      }
    }
    .sheet(isPresented: $picking) {
      RecordPickerSheet(model: model, picker: picker, tank: tank, current: value, onPick: onChange)
    }
  }

  private var row: FormPickerRow? { value.map { model.row($0, picker) } }

  private var prompt: String { picker.placeholder(holdsSome: false) }
}

#Preview {
  Form {
    RecordPickerField(
      model: DiveFormModel(session: DivePreviewData.session, mode: .create), title: "Trip",
      picker: .trip, value: nil
    ) { _ in }
  }
}
