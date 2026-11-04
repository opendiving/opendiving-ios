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
          title: title, value: value.map { model.row($0, picker).title } ?? prompt,
          isPending: value.map { model.row($0, picker).isPending } ?? false
        ) { picking = true }
      } else {
        stacked
      }
    }
    .sheet(isPresented: $picking) {
      RecordPickerSheet(model: model, picker: picker, tank: tank, current: value, onPick: onChange)
    }
  }

  private var prompt: String { picker.placeholder(holdsSome: false) }

  private var stacked: some View {
    VStack(alignment: .leading, spacing: 6) {
      FieldLabel(title)
      Button {
        picking = true
      } label: {
        HStack {
          if let value {
            PickerRowLabel(row: model.row(value, picker))
          } else {
            Text(prompt).foregroundStyle(.secondary)
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
