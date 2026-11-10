import SwiftUI
import UIKit

/// A value to hand on — an API key, a link's address — selectable, with a *Copy* that says it
/// copied for a moment. What it shows is hidden whenever the app is not active, so the app
/// switcher's snapshot of the screen, which is a file, never holds it.
struct CopyField: View {
  let value: String
  /// Names the value for VoiceOver.
  let label: String
  /// What *Copy* says for a moment once it has: "API key copied".
  let copied: String
  /// For a value read character by character.
  var monospaced = false

  @Environment(\.scenePhase) private var scenePhase
  @State private var showsCopied = false
  /// Counts copies, so a second keeps *Copied* up for its own while.
  @State private var copies = 0

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Group {
        if scenePhase == .active {
          Text(value)
            .textSelection(.enabled)
            .accessibilityLabel(label)
            .accessibilityValue(value)
        } else {
          Text(String(repeating: "\u{2022}", count: 16))
            .accessibilityHidden(true)
        }
      }
      .font(monospaced ? .callout.monospaced() : .callout)
      .frame(maxWidth: .infinity, alignment: .leading)
      Button {
        UIPasteboard.general.string = value
        withAnimation(.easeOut(duration: 0.15)) { showsCopied = true }
        copies += 1
      } label: {
        Label(
          showsCopied ? copied : "Copy", systemImage: showsCopied ? "checkmark" : "doc.on.doc")
      }
      .buttonStyle(.bordered)
      .contentTransition(.opacity)
      .sensoryFeedback(.success, trigger: copies)
    }
    .task(id: copies) {
      guard copies > 0 else { return }
      try? await Task.sleep(for: .seconds(1.5))
      guard !Task.isCancelled else { return }
      withAnimation(.easeOut(duration: 0.15)) { showsCopied = false }
    }
  }
}

#Preview {
  List {
    CopyField(
      value: "odk_Hn4tW7cEexampleSecretNotARealKey0123456789a", label: "New API key",
      copied: "API key copied", monospaced: true)
  }
}
