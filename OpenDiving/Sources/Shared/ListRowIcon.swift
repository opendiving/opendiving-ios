import OpenDivingKit
import SwiftUI

/// The symbol at the head of a row on a list's card, in a muted circle: what kind of record each
/// row is, as the people and contacts lists draw it.
struct ListRowIcon: View {
  let icon: OpenDivingKit.Icon

  static let side: CGFloat = 36
  /// Where the text of a row that leads with the icon starts, which the rule between two rows
  /// starts under.
  static let textInset: CGFloat = 12 + side + 12

  var body: some View {
    Image(icon)
      .resizable()
      .scaledToFit()
      .padding(Self.side / 4)
      .frame(width: Self.side, height: Self.side)
      .foregroundStyle(.secondary)
      .background(Color(.tertiarySystemFill), in: Circle())
      .accessibilityHidden(true)
  }
}

#Preview {
  HStack(spacing: 16) {
    ListRowIcon(icon: .user)
    ListRowIcon(icon: .building2)
  }
  .padding()
  .background(Color.cardFill)
}
