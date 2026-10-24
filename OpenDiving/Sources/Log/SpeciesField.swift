import OpenDivingKit
import SwiftUI

/// The species spotted: each with how many — a count, or one of the web's quick choices — and
/// notes, and the picker that adds the next.
struct SpeciesField: View {
  let model: DiveFormModel

  @State private var picking = false

  var body: some View {
    let sightings = model.values.sightings
    VStack(alignment: .leading, spacing: 10) {
      FieldLabel(DiveFormField.sightings.label)
      ForEach(Array(sightings.enumerated()), id: \.element.speciesUuid) { index, sighting in
        SightingRow(model: model, index: index, sighting: sighting)
      }
      Button(sightings.isEmpty ? "Select a species..." : "Add another species...") {
        picking = true
      }
      .buttonStyle(.borderless)
    }
    .sheet(isPresented: $picking) {
      SpeciesPickerSheet(model: model)
    }
  }
}

/// One sighting: the species, *Count* with *One*, *Few*, *Many* and *Abundant* beside it — one
/// answer per row — and its notes.
private struct SightingRow: View {
  let model: DiveFormModel
  let index: Int
  let sighting: SightingWrite

  @State private var count = ""
  @FocusState private var countFocused: Bool

  var body: some View {
    let name = model.speciesName(sighting.speciesUuid)
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(name).font(.body.weight(.medium))
        Spacer()
        Button {
          model.change { $0.sightings.removeAll { $0.speciesUuid == sighting.speciesUuid } }
        } label: {
          Image(systemName: "xmark")
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Remove \(name)")
      }
      HStack(spacing: 6) {
        TextField("Count", text: $count)
          .keyboardType(.numberPad)
          .focused($countFocused)
          .frame(maxWidth: 70)
          .textFieldStyle(.roundedBorder)
          .accessibilityLabel("Count of \(name)")
          .onChange(of: count) { _, typed in
            guard countFocused else { return }
            model.setCount(typed, sighting: index)
          }
        ForEach(["one"] + FormVocabulary.abundances, id: \.self) { key in
          quickChoice(key)
        }
      }
      if let message = model.message("sightings", index: index, member: "count")
        ?? model.message("sightings", index: index, member: "abundance")
      {
        FieldMessage(message)
      }
      TextField(
        "Notes",
        text: Binding(
          get: { sighting.notes },
          set: { text in
            model.change { values in
              guard values.sightings.indices.contains(index) else { return }
              values.sightings[index].notes = text
            }
          }), axis: .vertical
      )
      .font(.subheadline)
      if let message = model.message("sightings", index: index, member: "notes") {
        FieldMessage(message)
      }
    }
    .padding(.vertical, 4)
    .onAppear { count = sighting.count.map(String.init) ?? "" }
    .onChange(of: sighting.count) { _, now in
      if !countFocused { count = now.map(String.init) ?? "" }
    }
  }

  private func quickChoice(_ key: String) -> some View {
    let chosen = key == "one" ? sighting.count == 1 : sighting.abundance == key
    let label = key == "one" ? "One" : VocabularyLabels.abundance(key)
    let range = key == "one" ? "1" : (VocabularyLabels.abundanceRange(key) ?? "")
    return Button {
      model.chooseQuantity(key, sighting: index)
    } label: {
      VStack(spacing: 0) {
        Text(label).font(.caption.weight(.semibold))
        Text(range).font(.caption2).foregroundStyle(chosen ? .primary : .secondary)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 4)
      .background(
        RoundedRectangle(cornerRadius: 6)
          .fill(chosen ? Color.accentColor.opacity(0.25) : Color(.secondarySystemFill)))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(key == "one" ? label : "\(label), \(range)")
    .accessibilityAddTraits(chosen ? .isSelected : [])
  }
}

#Preview {
  Form {
    SpeciesField(model: DiveFormModel(session: DivePreviewData.session, mode: .create))
  }
}
