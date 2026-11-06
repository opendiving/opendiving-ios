import OpenDivingKit
import SwiftUI

/// A record's own fields in its form's groups, read-only, a field with nothing recorded showing
/// a dash.
struct RecordInfoSheet: View {
  let title: String
  let sections: [RecordInfoSection]

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
          Section {
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
          } header: {
            if let heading = section.heading {
              Text(heading)
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
