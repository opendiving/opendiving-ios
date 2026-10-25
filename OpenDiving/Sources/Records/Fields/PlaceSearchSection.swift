import OpenDivingKit
import SwiftUI

/// A place search box and what it found, as the web's place comboboxes list it: a row per
/// result with its hint, the line saying why there are none, *Use “…”* for a name no result
/// matched — the web's Enter — and the credits every row shown so far owes.
struct PlaceSearchSection: View {
  let model: PlaceSearchModel
  @Binding var query: String
  var position: DeviceLocation?
  let units: UnitSystem
  let onPick: (PlacePick) -> Void
  let onTypeName: (String) -> Void

  var body: some View {
    Section {
      TextField("Search", text: $query, prompt: Text(model.text.placeholder))
        .autocorrectionDisabled()
        .submitLabel(.done)
        .onSubmit(useTyped)
      results
      if !trimmed.isEmpty {
        Button("Use “\(trimmed)”", action: useTyped)
      }
    } footer: {
      if !model.attributions.isEmpty {
        AttributionLine(credits: model.attributions)
      }
    }
    .task(id: query) { await model.search(query, near: position, units: units) }
  }

  @ViewBuilder private var results: some View {
    switch model.state {
    case .idle: note(model.text.noItems)
    case .tooLong: note(model.text.queryTooLong)
    case .searching: ProgressView()
    case .noMatches: note(model.text.noMatches)
    case .failed: note(model.text.searchError)
    case .results(let rows, let hasMore):
      ForEach(rows) { row in
        Button {
          onPick(row.pick)
          query = ""
          model.clear()
        } label: {
          VStack(alignment: .leading) {
            Text(row.name).foregroundStyle(.primary)
            if let hint = row.hint {
              Text(hint).font(.footnote).foregroundStyle(.secondary)
            }
          }
        }
      }
      if hasMore { note("More matches than shown - keep typing to narrow.") }
    }
  }

  private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

  private func note(_ text: String) -> some View {
    Text(text).font(.footnote).foregroundStyle(.secondary)
  }

  private func useTyped() {
    guard !trimmed.isEmpty else { return }
    onTypeName(trimmed)
    query = ""
    model.clear()
  }
}

#Preview {
  @Previewable @State var query = ""
  List {
    PlaceSearchSection(
      model: PlaceSearchModel(text: .tripPart, catalog: nil, geocode: { _ in [] }),
      query: $query, units: .metric, onPick: { _ in }, onTypeName: { _ in })
  }
}
