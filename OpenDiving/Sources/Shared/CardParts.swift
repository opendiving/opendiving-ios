import OpenDivingKit
import SwiftUI

/// The chips over a title: vocabulary abbreviations bordered in the text's colour, tags
/// filled. Nothing at all when there are none.
struct ChipsRow: View {
  let chips: [Chip]

  var body: some View {
    if !chips.isEmpty {
      FlowLayout(spacing: 4) {
        ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
          ChipView(chip: chip)
        }
      }
    }
  }
}

private struct ChipView: View {
  let chip: Chip

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 3)
    Text(chip.text)
      .font(.caption2.weight(.semibold))
      .lineLimit(1)
      .padding(.horizontal, 4)
      .padding(.vertical, 1)
      .foregroundStyle(chip.kind == .tag ? Color.white : Color.primary)
      .background {
        switch chip.kind {
        case .vocabulary: shape.strokeBorder(Color.primary)
        case .tag: shape.fill(Color.teal)
        }
      }
      .accessibilityLabel(chip.accessibilityLabel)
  }
}

/// A record's name, followed by a graduation cap for a course dive and its rating in stars.
struct TitleLine: View {
  let title: String
  var isCourse = false
  var rating: Int?
  var font: Font = .headline

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text(title)
        .font(font)
      if isCourse {
        Image(systemName: "graduationcap")
          .font(font)
          .accessibilityLabel("Training dive")
      }
      if let rating {
        RatingStars(rating: rating)
          .font(.caption)
      }
    }
  }
}

/// A stored rating as five stars, read out once as "4 of 5 stars".
struct RatingStars: View {
  static let maximum = 5
  let rating: Int

  var body: some View {
    HStack(spacing: 1) {
      ForEach(1...Self.maximum, id: \.self) { step in
        Image(systemName: step <= rating ? "star.fill" : "star")
          .foregroundStyle(step <= rating ? Color.orange : Color.secondary)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(rating) of \(Self.maximum) stars")
  }
}

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

/// Labelled figures, side by side and wrapping where they do not fit.
struct FiguresRow: View {
  let figures: [Figure]

  var body: some View {
    if !figures.isEmpty {
      FlowLayout(spacing: 12, lineSpacing: 8) {
        ForEach(Array(figures.enumerated()), id: \.offset) { _, figure in
          VStack(alignment: .leading, spacing: 0) {
            Text(figure.label)
              .font(.caption)
            Text(figure.value ?? "-")
              .font(.body.weight(.bold))
              .foregroundStyle(figure.value == nil ? Color.secondary : Color.primary)
              .lineLimit(1)
          }
          .frame(minWidth: 72, alignment: .leading)
          .accessibilityElement(children: .combine)
        }
      }
    }
  }
}
