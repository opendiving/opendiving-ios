import OpenDivingKit
import SwiftUI

/// The foot of a paged list: a spinner while the next page loads, and *Try again* once a
/// page has failed. Rows ask for the next page themselves, through
/// `PagedList.loadMore(after:)`, so the footer is empty while a list loads as it scrolls.
struct LoadMoreFooter: View {
  let isLoading: Bool
  let failed: Bool
  let retry: () -> Void

  var body: some View {
    Group {
      if isLoading {
        ProgressView()
      } else if failed {
        Button("Try again", action: retry)
          .buttonStyle(.bordered)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
  }
}

extension LoadMoreFooter {
  /// The footer of `list`. A failed later page is retried; a failed refresh, with nothing
  /// left to load, refreshes again.
  init<Item>(list: PagedList<Item>) {
    self.init(isLoading: list.isLoadingMore, failed: list.pageError != nil) {
      Task {
        if list.hasMore {
          await list.loadMore()
        } else {
          await list.refresh()
        }
      }
    }
  }
}

#Preview("Loading") {
  LoadMoreFooter(isLoading: true, failed: false) {}
}

#Preview("Failed") {
  LoadMoreFooter(isLoading: false, failed: true) {}
}
