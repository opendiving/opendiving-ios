import OpenDivingKit
import SwiftUI

/// The marine-life picker: the species the diver has logged, from the life list the phone
/// keeps, then — when the server can be asked — its suggestions, the dive's sites' species
/// first. A pick the catalogue does not hold yet is resolved before it goes on the dive.
struct SpeciesPickerSheet: View {
  let model: DiveFormModel

  @Environment(\.dismiss) private var dismiss
  @State private var text = ""
  @State private var found: [SpeciesPick] = []
  @State private var adding: SpeciesPick?
  @State private var failed = false

  var body: some View {
    NavigationStack {
      let rows = model.speciesRows(matching: text)
      List {
        if failed {
          FieldMessage("Couldn't add that species.")
        }
        ForEach(rows + found.filter { pick in !rows.contains { $0.uuid == pick.uuid } }) { pick in
          Button {
            add(pick)
          } label: {
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text(pick.title).foregroundStyle(.primary)
                if let subtitle = pick.subtitle {
                  Text(subtitle).font(.subheadline).italic().foregroundStyle(.secondary)
                }
                if let attribution = pick.attribution {
                  Text(attribution).font(.caption2).foregroundStyle(.tertiary)
                }
              }
              Spacer()
              if adding == pick { ProgressView() }
            }
          }
          .disabled(adding != nil)
        }
        if rows.isEmpty && found.isEmpty {
          Text(text.isEmpty ? "Type a species name — common or scientific." : "No species found.")
            .foregroundStyle(.secondary)
        }
      }
      .searchable(
        text: $text, placement: .navigationBarDrawer(displayMode: .always),
        prompt: "Select a species..."
      )
      .task(id: text) {
        found = []
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        found = await model.searchSpecies(text)
      }
      .navigationTitle("Species spotted")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
    }
  }

  private func add(_ pick: SpeciesPick) {
    adding = pick
    failed = false
    Task {
      let added = await model.addSpecies(pick)
      adding = nil
      if added { dismiss() } else { failed = true }
    }
  }
}

#Preview {
  SpeciesPickerSheet(model: DiveFormModel(session: DivePreviewData.session, mode: .create))
}
