import OpenDivingKit
import SwiftUI

/// A record's own fields under its form's headings, read-only, a field with nothing recorded
/// showing a dash.
struct RecordInfoSheet: View {
  let title: String
  let sections: [RecordInfoSection]

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        ForEach(sections, id: \.heading) { section in
          Section(section.heading) {
            ForEach(section.facts, id: \.label) { fact in
              if fact.isWide, let value = fact.value {
                VStack(alignment: .leading, spacing: 4) {
                  Text(fact.label)
                  Text(value).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
              } else {
                LabeledContent(fact.label, value: fact.value ?? "-")
              }
            }
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

#Preview {
  RecordInfoSheet(
    title: "Dive Information",
    sections: [
      RecordInfoSection(
        heading: "Dive Info",
        facts: [
          RecordInfoFact(label: "Dive number", value: "212"),
          RecordInfoFact(label: "Average depth", value: "18.2 m"),
          RecordInfoFact(label: "Maximum depth", value: nil),
        ]),
      RecordInfoSection(
        heading: "Notes",
        facts: [
          RecordInfoFact(label: "Notes", value: "A turtle on the safety stop.", isWide: true)
        ]),
    ])
}
