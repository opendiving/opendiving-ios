import OpenDivingKit
import SwiftUI

/// A block's list while it is not there to show: loading, or why it could not be read.
struct OptionalListStatus<Value: Sendable>: View {
  let list: OptionalList<Value>
  /// The web's sentence for a list that could not be read.
  let failed: String
  let loading: String

  var body: some View {
    if let failure = list.failure, list.value == nil {
      VStack(alignment: .leading, spacing: 8) {
        Text(failed + " " + failure)
          .foregroundStyle(.secondary)
        Button("Try again") { Task { await list.load() } }
          .needsServer()
          .buttonStyle(.borderless)
          .accentRow()
      }
    } else if list.value == nil {
      HStack {
        BubbleSpinner()
        Text(loading)
      }
      .foregroundStyle(.secondary)
    }
  }
}
