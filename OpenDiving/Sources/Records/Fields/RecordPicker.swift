import OpenDivingKit
import SwiftUI

/// One record picked from what the phone holds — a dive centre, an instructor, a place to stay
/// — as the web's comboboxes pick one, *Add…* opening that record's own sheet over this one and
/// selecting what it makes.
struct RecordPicker<Row: LookupRow, NewSheet: View>: View {
  let label: String
  let placeholder: String
  let addLabel: String
  let rows: [Row]
  @Binding var selection: RecordRef?
  /// The sheet that makes a new record, handed what to do with its ref.
  let newSheet: (@escaping (RecordRef) -> Void) -> NewSheet

  @State private var adding = false

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label).font(.subheadline.weight(.medium))
      NavigationLink {
        RecordPickerList(
          title: label, rows: rows, selection: $selection, addLabel: addLabel,
          add: { adding = true })
      } label: {
        HStack {
          Text(selectedTitle ?? placeholder)
            .foregroundStyle(selectedTitle == nil ? .secondary : .primary)
          if selection?.isLocal == true { PendingMark() }
        }
      }
    }
    .sheet(isPresented: $adding) {
      newSheet { ref in selection = ref }
    }
  }

  private var selectedTitle: String? {
    guard let selection else { return nil }
    return rows.first { $0.ref == selection }?.title ?? "New record"
  }
}

/// The list a picker pushes: a search over the rows, *None*, and *Add…*.
struct RecordPickerList<Row: LookupRow>: View {
  let title: String
  let rows: [Row]
  @Binding var selection: RecordRef?
  let addLabel: String
  let add: () -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var search = ""

  var body: some View {
    List {
      Section {
        Button(addLabel) {
          dismiss()
          add()
        }
        if selection != nil {
          Button("None", role: .destructive) {
            selection = nil
            dismiss()
          }
        }
      }
      Section {
        ForEach(LookupsModel.matching(rows, search), id: \.ref) { row in
          Button {
            selection = row.ref
            dismiss()
          } label: {
            HStack {
              VStack(alignment: .leading) {
                Text(row.title).foregroundStyle(.primary)
                if let subtitle = row.subtitle {
                  Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                }
                if row.ref.isLocal { PendingMark() }
              }
              Spacer()
              if row.ref == selection {
                Image(systemName: "checkmark").foregroundStyle(.tint)
              }
            }
          }
        }
      }
    }
    .searchable(text: $search)
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  @Previewable @State var selection: RecordRef?
  NavigationStack {
    Form {
      RecordPicker(
        label: "Dive center", placeholder: "Select a dive center...",
        addLabel: "Add dive center...", rows: [PersonLookupItem](), selection: $selection
      ) { _ in Text("New") }
    }
  }
}
