import OpenDivingKit
import SwiftUI

extension DiveSiteMark {
  /// Coral for the Commons, teal for a proposal and grey for the diver's alone, on the map as
  /// beside the word.
  var color: Color {
    switch self {
    case .commons: .brandCoral
    case .proposed: .brandTeal
    case .private: Color(.systemGray)
    }
  }
}

/// The symbol before a site's mark: the Commons' bubbles in coral, the same in teal on a proposed
/// site, and a grey lock on a private one.
struct DiveSiteMarkIcon: View {
  let mark: DiveSiteMark
  /// Unscaled, for the Commons mark, which scales it itself.
  private let baseSide: CGFloat
  @ScaledMetric private var side: CGFloat
  private let textStyle: Font.TextStyle

  init(mark: DiveSiteMark, side: CGFloat = 14, relativeTo textStyle: Font.TextStyle = .caption) {
    self.mark = mark
    baseSide = side
    self.textStyle = textStyle
    _side = ScaledMetric(wrappedValue: side, relativeTo: textStyle)
  }

  var body: some View {
    switch mark {
    case .commons, .proposed:
      CommonsMark(side: baseSide, relativeTo: textStyle, color: mark.color)
    case .private:
      Image(Icon.lock)
        .resizable()
        .scaledToFit()
        .frame(width: side, height: side)
        .foregroundStyle(mark.color)
        .accessibilityHidden(true)
    }
  }
}

#Preview {
  HStack(spacing: 16) {
    ForEach(DiveSiteMark.allCases, id: \.self) { DiveSiteMarkIcon(mark: $0, side: 32) }
  }
  .padding()
}
