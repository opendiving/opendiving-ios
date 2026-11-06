import SwiftUI

/// A short label in a capsule: a gear item's Rented and Archived, a gas and its role, a
/// site's tags, a card's agency and expiry, and a Commons site's mark before its word.
struct BadgeView<Icon: View>: View {
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
  @ViewBuilder let icon: Icon

  init(_ text: String, style: Style = .secondary, @ViewBuilder icon: () -> Icon) {
    self.text = text
    self.style = style
    self.icon = icon()
  }

  var body: some View {
    HStack(spacing: 4) {
      icon
      Text(text)
    }
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
    case .teal: .brandTeal
    case .coral: .brandCoral
    case .destructive: .dangerFill
    }
  }
}

extension BadgeView where Icon == EmptyView {
  init(_ text: String, style: Style = .secondary) {
    self.init(text, style: style) { EmptyView() }
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
    BadgeView("Commons", style: .outline) { CommonsMark() }
  }
  .padding()
}
