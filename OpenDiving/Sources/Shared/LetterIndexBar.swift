import OpenDivingKit
import SwiftUI

/// The column of letters at a list's trailing edge, as the phone's contacts draw it: a touch on a
/// letter, or a finger dragged down the column, picks it, with a tick for each letter crossed.
/// VoiceOver reads it as one control, swiped up and down a letter at a time.
struct LetterIndexBar: View {
  let letters: [String]
  let onSelect: (String) -> Void

  @State private var selected: String?
  @State private var height: CGFloat = 0

  /// Each letter's share of the column, less where the screen leaves too little for them all.
  static let letterHeight: CGFloat = 16
  static let width: CGFloat = 20

  var body: some View {
    GeometryReader { proxy in
      let rowHeight = min(Self.letterHeight, proxy.size.height / CGFloat(max(letters.count, 1)))
      VStack(spacing: 0) {
        ForEach(letters, id: \.self) { letter in
          Text(letter)
            .font(.caption2.weight(.semibold))
            .minimumScaleFactor(0.5)
            .foregroundStyle(Color.accentText)
            .frame(width: Self.width, height: rowHeight)
        }
      }
      .onGeometryChange(for: CGFloat.self) {
        $0.size.height
      } action: {
        height = $0
      }
      .contentShape(.rect)
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged {
            pick(LetterIndex.letter(at: $0.location.y, height: height, letters: letters))
          }
          .onEnded { _ in selected = nil }
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(width: Self.width)
    .sensoryFeedback(.selection, trigger: selected) { _, new in new != nil }
    .accessibilityElement()
    .accessibilityLabel("Index")
    .accessibilityValue(selected ?? letters.first ?? "")
    .accessibilityAdjustableAction { direction in
      // With nothing picked the value reads the first letter, so a step moves on from it.
      let current = selected.flatMap { letters.firstIndex(of: $0) } ?? 0
      let next: Int
      switch direction {
      case .increment: next = current + 1
      case .decrement: next = current - 1
      @unknown default: return
      }
      guard letters.indices.contains(next) else { return }
      pick(letters[next])
    }
  }

  private func pick(_ letter: String?) {
    guard let letter, letter != selected else { return }
    selected = letter
    onSelect(letter)
  }
}

#Preview {
  HStack {
    Spacer()
    LetterIndexBar(letters: ["A", "B", "D", "K", "M", "S", "Z", "#"]) { _ in }
  }
  .frame(height: 400)
  .background(Color.pageBackground)
}
