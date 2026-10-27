import OpenDivingKit
import SwiftUI

/// What a list or a detail shows in place of its content. `retry` is offered on a failure
/// as *Try again*, and nowhere else.
struct EmptyOrErrorView: View {
  let status: ContentStatus
  var retry: (() -> Void)?

  var body: some View {
    switch status {
    case .loading:
      ProgressView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .empty(let systemImage, let title, let message):
      ContentUnavailableView {
        Label(title, systemImage: systemImage)
      } description: {
        if let message {
          Text(message)
        }
      }
    case .notFound(let message):
      ContentUnavailableView(message, systemImage: "questionmark.circle")
    case .failed(let message):
      ContentUnavailableView {
        Label("Something went wrong", systemImage: "exclamationmark.triangle")
      } description: {
        Text(message)
      } actions: {
        if let retry {
          Button("Try again", action: retry)
            .buttonStyle(.bordered)
        }
      }
    }
  }
}

#Preview("Empty") {
  EmptyOrErrorView(
    status: .empty(
      systemImage: "water.waves", title: "No dives logged yet",
      message:
        "No dives yet. Log one, import your dive computer's files, or connect your dive "
        + "computer, with +."
    ))
}

#Preview("Failed") {
  EmptyOrErrorView(status: .failed(message: "The server could not be reached.")) {}
}

#Preview("Loading") {
  EmptyOrErrorView(status: .loading)
}
