import OpenDivingKit
import SwiftUI

/// A course's *Add dives* or *Add certifications*: the records not on the course yet as a plain
/// list to tick, *+* at the top for a new one made on the course, and the button at the bottom
/// moving the ticked ones onto it.
struct CourseAttachView<Item: Codable & Sendable & Identifiable, NewForm: View>: View
where Item.ID == UUID {
  struct Words {
    let title: String
    let one: String
    let many: String
    let newLabel: String
    let empty: String
    let emptyIcon: Icon
    let offline: String
  }

  let words: Words
  @State var list: PagedList<Item>
  let offered: ([Item]) -> [Item]
  let row: (Item) -> CourseAttach.Row
  let attach: ([UUID]) -> String?
  @ViewBuilder let newForm: () -> NewForm

  @Environment(\.dismiss) private var dismiss
  @State private var selection = Set<UUID>()
  @State private var creating = false
  @State private var error: String?

  var body: some View {
    content
      .navigationTitle(words.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(words.newLabel, systemImage: "plus") { creating = true }
        }
      }
      .navigationDestination(isPresented: $creating) { newForm() }
      .pinnedToBottom {
        FormSaveBar(
          label: CourseAttach.addLabel(selection.count, one: words.one, many: words.many),
          error: error, action: add
        )
        .disabled(selection.isEmpty)
      }
      .task { await list.load() }
  }

  @ViewBuilder private var content: some View {
    switch list.phase {
    case .idle, .loading:
      EmptyOrErrorView(status: .loading)
    case .failed(let error):
      EmptyOrErrorView(
        status: .failed(message: error.isUnreachable ? words.offline : error.message)
      ) {
        Task { await list.refresh() }
      }
    case .loaded:
      let items = offered(list.items)
      if items.isEmpty, list.hasMore, list.pageError == nil {
        // Every row read so far is on the course already: read on until one is not.
        BubbleSpinner()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .task(id: list.items.count) { await list.loadMore() }
      } else if items.isEmpty {
        EmptyOrErrorView(status: .empty(icon: words.emptyIcon, title: words.empty, message: nil))
      } else {
        // Ticked by hand rather than by the list's edit mode, whose circle iOS 26 colours as
        // it likes and whose selected row is a heavy grey.
        List {
          ForEach(items) { item in
            let isPicked = selection.contains(item.id)
            Button {
              if isPicked { selection.remove(item.id) } else { selection.insert(item.id) }
            } label: {
              CourseAttachRow(row: row(item), isPicked: isPicked)
            }
            .buttonStyle(.plain)
            .listRowBackground(
              isPicked ? Color.pickedRow : Color(.secondarySystemGroupedBackground)
            )
            .accessibilityAddTraits(isPicked ? .isSelected : [])
            // The course's own rows are left out, so the last row shown need not be the list's.
            .onAppear {
              if item.id == items.last?.id { Task { await list.loadMore() } }
            }
          }
        }
      }
    }
  }

  private func add() {
    let picked = offered(list.items).map(\.id).filter(selection.contains)
    error = attach(picked)
    if error == nil { dismiss() }
  }
}

/// One row to tick: the brand teal's filled tick or an empty ring, then the record's two lines.
private struct CourseAttachRow: View {
  let row: CourseAttach.Row
  let isPicked: Bool

  var body: some View {
    HStack(spacing: 12) {
      Group {
        if isPicked {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.white, Color.brandTeal)
        } else {
          Image(systemName: "circle")
            .foregroundStyle(Color(.tertiaryLabel))
        }
      }
      .font(.title2)
      .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(row.title)
        Text(row.detail)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .contentShape(.rect)
  }
}

#Preview {
  NavigationStack {
    CourseAttachView(
      words: .init(
        title: "Add dives", one: "dive", many: "dives", newLabel: "Log a dive",
        empty: "No other dives to add", emptyIcon: .dive, offline: OfflineText.divesNotShown),
      list: .allDives(DivePreviewData.session),
      offered: { $0 },
      row: { CourseAttach.row($0, units: .metric) },
      attach: { _ in nil },
      newForm: { Text("New dive") }
    )
  }
  .environment(DivePreviewData.session)
}
