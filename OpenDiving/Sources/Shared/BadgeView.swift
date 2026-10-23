import SwiftUI

/// A short label in a capsule: a gear item's Rented and Archived, a gas and its role, a
/// site's tags, a card's agency and expiry.
struct BadgeView: View {
  /// The web's badge variants that the phone's screens use.
  enum Style {
    /// Muted fill, as Rented and a gas name.
    case secondary
    /// Bordered, no fill, as Archived, a site's tags and an agency.
    case outline
    /// The brand's teal, as a gas role.
    case teal
    /// The brand's coral, as a card nearing expiry.
    case coral
    /// As an expired card.
    case destructive
  }

  let text: String
  let style: Style

  init(_ text: String, style: Style = .secondary) {
    self.text = text
    self.style = style
  }

  var body: some View {
    Text(text)
      .font(.caption.weight(.semibold))
      .lineLimit(1)
      .padding(.horizontal, 10)
      .padding(.vertical, 2)
      .foregroundStyle(foreground)
      .background {
        switch style {
        case .outline: Capsule().strokeBorder(Color(.separator))
        default: Capsule().fill(fill)
        }
      }
  }

  private var foreground: Color {
    switch style {
    case .secondary, .outline: .primary
    case .teal, .coral, .destructive: .white
    }
  }

  private var fill: Color {
    switch style {
    case .secondary: Color(.secondarySystemFill)
    case .outline: .clear
    case .teal: .teal
    case .coral: .orange
    case .destructive: .red
    }
  }
}

#Preview {
  VStack(alignment: .leading, spacing: 8) {
    HStack {
      BadgeView("Rented")
      BadgeView("Archived", style: .outline)
    }
    HStack {
      BadgeView("EAN32")
      BadgeView("Bottom gas", style: .teal)
    }
    HStack {
      BadgeView("PADI", style: .outline)
      BadgeView("Expires in 20 days", style: .coral)
      BadgeView("Expired", style: .destructive)
    }
  }
  .padding()
}
