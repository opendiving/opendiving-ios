import SwiftUI

/// Rows of a form's list that drag to a new place and swipe away, with VoiceOver's *Move up* and
/// *Move down* for the drag it cannot do. A row draws its own ``DragHandle``, where it has room.
struct SortableRows<Item, ID: Hashable, Row: View>: View {
  @Binding var items: [Item]
  /// What stays the same as a row's item is edited.
  let identity: (Item) -> ID
  /// What VoiceOver calls the row.
  let title: (Item) -> String
  @ViewBuilder let row: (Int, Item) -> Row

  var body: some View {
    ForEach(entries) { entry in
      let name = title(entry.item)
      row(entry.index, entry.item)
        .accessibilityActions {
          if entry.index > 0 {
            Button("Move \(name) up") { move(entry.id, by: -1) }
          }
          if entry.index < items.count - 1 {
            Button("Move \(name) down") { move(entry.id, by: 1) }
          }
        }
        .swipeToDelete { items.removeAll { identity($0) == entry.id } }
    }
    .onMove { items.move(fromOffsets: $0, toOffset: $1) }
  }

  private var entries: [Entry] {
    items.enumerated().map { Entry(id: identity($1), index: $0, item: $1) }
  }

  /// By identity, not the index the row drew with: the list may have moved since.
  private func move(_ id: ID, by offset: Int) {
    guard let index = items.firstIndex(where: { identity($0) == id }),
      items.indices.contains(index + offset)
    else { return }
    items.swapAt(index, index + offset)
  }

  private struct Entry: Identifiable {
    let id: ID
    let index: Int
    let item: Item
  }
}

#Preview {
  @Previewable @State var names = ["Blue Hole", "Blue Corner"]
  Form {
    SortableRows(
      items: $names, identity: { $0 }, title: { $0 },
      row: { _, name in
        HStack {
          Text(name)
          Spacer()
          DragHandle()
        }
      })
  }
}
