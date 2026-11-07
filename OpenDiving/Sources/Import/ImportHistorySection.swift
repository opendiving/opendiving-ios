import OpenDivingKit
import SwiftUI

/// The applied imports, newest first, page by page so that an older one stays reachable. Absent
/// until there is one to list.
struct ImportHistorySection: View {
  let list: PagedList<LogbookImportSummary>

  var body: some View {
    if case .failed(let error) = list.phase {
      Section("Previous Imports") {
        Text(error.message).font(.footnote).foregroundStyle(.secondary)
        Button("Try again") { Task { await list.load() } }
          .accentRow()
      }
    } else if !list.items.isEmpty {
      Section("Previous Imports") {
        ForEach(list.items) { item in
          NavigationLink {
            ImportDetailView(uuid: item.uuid)
          } label: {
            VStack(alignment: .leading, spacing: 2) {
              Text(ImportText.when(item.appliedAt)).font(.subheadline.weight(.medium))
              Text(ImportText.counts(item.counts)).font(.caption).foregroundStyle(.secondary)
            }
          }
          .task { await list.loadMore(after: item) }
        }
        if list.isLoadingMore || list.pageError != nil {
          LoadMoreFooter(list: list)
        }
      }
    }
  }
}

extension ImportHistorySection {
  /// The account's applied imports, from `GET /imports`.
  static func list(_ session: Session) -> PagedList<LogbookImportSummary> {
    PagedList(session: session) { client, page, itemsPerPage in
      try await client.imports(page: page, itemsPerPage: itemsPerPage)
    }
  }
}

#Preview {
  let session = ImportPreviewData.session
  let list = ImportHistorySection.list(session)
  NavigationStack {
    List {
      ImportHistorySection(list: list)
    }
  }
  .environment(session)
  .task { await list.load() }
}
