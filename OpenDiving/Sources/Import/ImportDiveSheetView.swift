import OpenDivingKit
import SwiftUI

/// What a card of an import opens: a new dive whole, or what changes on a dive the diver has.
struct ImportDiveSheetView: View {
  let sheet: ImportDiveSheet

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    switch sheet {
    case .info(let title, let sections):
      RecordInfoSheet(title: title, sections: sections)
    case .changes(let title, let rows, let opens):
      NavigationStack {
        List {
          if let opens {
            Section {
              NavigationLink("Open this dive") {
                DiveDetailView(diveUUID: opens)
              }
            }
          }
          Section {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
              ImportChangeRowView(row: row)
            }
          }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
          }
        }
      }
    }
  }
}

/// One change: a sentence for an element, or a label over what it was and what it becomes.
private struct ImportChangeRowView: View {
  let row: ImportChangeRow

  var body: some View {
    switch row {
    case .element(let text):
      Text(text).font(.subheadline.weight(.medium))
    case .value(let label, let before, let after):
      VStack(alignment: .leading, spacing: 2) {
        Text(label).font(.caption).foregroundStyle(.secondary)
        (Text(before + " → ").foregroundStyle(.secondary) + Text(after).fontWeight(.medium))
          .font(.subheadline)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("\(label), was \(before), becomes \(after)")
    }
  }
}

#Preview("Changes") {
  ImportDiveSheetView(
    sheet: .changes(
      title: "#212 Blue Hole",
      rows: [
        .value(label: "Maximum depth", before: "23.4 m", after: "23.6 m"),
        .element("File added — dive-0214.fit"),
      ],
      opens: UUID()))
}

#Preview("New dive") {
  ImportDiveSheetView(
    sheet: .info(
      title: "#212 Blue Hole",
      sections: [
        RecordInfoSection(
          heading: "Tanks", facts: [RecordInfoFact(label: "Tank 1", value: "EAN32 · 12 L")])
      ]))
}
