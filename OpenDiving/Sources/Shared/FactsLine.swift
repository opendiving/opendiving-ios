import OpenDivingKit
import SwiftUI

/// The dot-separated line under a title.
struct FactsLine: View {
  let facts: [Fact]

  var body: some View {
    if !facts.isEmpty {
      FlowLayout(spacing: 4, lineSpacing: 2) {
        ForEach(Array(facts.enumerated()), id: \.offset) { index, fact in
          HStack(spacing: 4) {
            if index > 0 {
              Text("·").accessibilityHidden(true)
            }
            FactView(fact: fact)
          }
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }
}

private struct FactView: View {
  let fact: Fact

  var body: some View {
    switch (fact.text, fact.systemImage) {
    case (let text?, let image?):
      Label(text, systemImage: image)
        .labelStyle(.titleAndIcon)
        .accessibilityLabel(fact.accessibilityLabel.map { "\($0): \(text)" } ?? text)
    case (let text?, nil):
      Text(text)
        .accessibilityLabel(fact.accessibilityLabel ?? text)
    case (nil, let image?):
      Image(systemName: image)
        .accessibilityLabel(fact.accessibilityLabel ?? "")
    case (nil, nil):
      EmptyView()
    }
  }
}

#Preview {
  FactsLine(facts: [
    Fact(text: "Apr 4, 2021, 10:04"),
    Fact(text: "Dahab, Egypt"),
    Fact(text: "Legend", systemImage: "ferry", accessibilityLabel: "Boat"),
    Fact(systemImage: "paperclip", accessibilityLabel: "Recording attached"),
  ])
  .padding()
}
