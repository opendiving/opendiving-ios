import SwiftUI

/// A list's section index down its trailing edge, as Contacts draws one: a letter each, chosen
/// by a tap or by sliding a finger along it, and stepped through by VoiceOver's swipes.
struct SectionIndexBar: View {
  let letters: [String]
  let select: (String) -> Void

  @State private var current: String?

  /// Fixed, as the system's index is, so every letter fits the height of the screen at any text
  /// size; VoiceOver reads it as one adjustable control instead.
  private static let letterHeight: CGFloat = 16

  var body: some View {
    VStack(spacing: 0) {
      ForEach(letters, id: \.self) { letter in
        Text(letter)
          .font(.system(size: 11, weight: .semibold))
          .frame(width: 16, height: Self.letterHeight)
      }
    }
    .foregroundStyle(Color.accentText)
    .contentShape(.rect)
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { value in
          guard !letters.isEmpty else { return }
          let index = Int(value.location.y / Self.letterHeight)
          choose(letters[min(max(index, 0), letters.count - 1)])
        }
        .onEnded { _ in current = nil }
    )
    .sensoryFeedback(.selection, trigger: current) { _, new in new != nil }
    .accessibilityElement()
    .accessibilityLabel("Section index")
    .accessibilityValue(current ?? letters.first ?? "")
    .accessibilityAdjustableAction { direction in
      let at = current.flatMap { letters.firstIndex(of: $0) } ?? 0
      let next =
        switch direction {
        case .increment: min(at + 1, letters.count - 1)
        case .decrement: max(at - 1, 0)
        @unknown default: at
        }
      choose(letters[next])
    }
  }

  private func choose(_ letter: String) {
    guard letter != current else { return }
    current = letter
    select(letter)
  }
}

#Preview {
  HStack {
    Spacer()
    SectionIndexBar(letters: ["A", "B", "C", "M", "Z", "#"]) { _ in }
  }
  .padding()
}
