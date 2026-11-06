import OpenDivingKit
import SwiftUI

/// The dot-separated line under a title.
struct FactsLine: View {
  let facts: [Fact]
  var color = Color.secondary

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
      .foregroundStyle(color)
    }
  }
}

private struct FactView: View {
  let fact: Fact

  var body: some View {
    switch (fact.text, fact.icon) {
    case (let text?, let image?):
      Label(text, icon: image)
        .labelStyle(.titleAndIcon)
        .accessibilityLabel(fact.accessibilityLabel.map { "\($0): \(text)" } ?? text)
    case (let text?, nil):
      Text(text)
        .accessibilityLabel(fact.accessibilityLabel ?? text)
    case (nil, let image?):
      HStack(spacing: 2) {
        ForEach(0..<fact.iconCount, id: \.self) { _ in
          Image(image)
        }
      }
      .accessibilityElement(children: .ignore)
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
    Fact(text: "Legend", icon: .ship, accessibilityLabel: "Boat"),
    Fact(icon: .diveComputer, iconCount: 2, accessibilityLabel: "2 dive computers"),
  ])
  .padding()
}
