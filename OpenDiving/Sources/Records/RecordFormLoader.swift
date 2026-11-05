import OpenDivingKit
import SwiftUI

/// Reads the record a refused edit opens over, which no page has handed the form.
struct RecordFormLoader<Read: Sendable, Content: View>: View {
  let read: @MainActor () async throws -> Read
  @ViewBuilder let content: (Read) -> Content

  @State private var loaded: Read?
  @State private var error: APIError?

  var body: some View {
    Group {
      if let loaded {
        content(loaded)
      } else if let error {
        EmptyOrErrorView(status: .failed(message: error.message)) {
          Task { await load() }
        }
      } else {
        EmptyOrErrorView(status: .loading)
      }
    }
    .task {
      guard loaded == nil else { return }
      await load()
    }
  }

  private func load() async {
    error = nil
    do {
      loaded = try await read()
    } catch {
      self.error = APIError(error)
    }
  }
}
