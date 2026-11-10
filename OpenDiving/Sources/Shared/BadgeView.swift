import OpenDivingKit
import SwiftUI

/// A short label in a capsule: a gear item's Rented and Archived, a gas and its role, a
/// site's tags, a card's agency and expiry, and a site's mark before its word.
struct BadgeView<Icon: View>: View {
  typealias Style = Badge.Style

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
    case .primary, .teal, .coral, .destructive: .white
    case .warning: Self.warningForeground
    }
  }

  private var fill: Color {
    switch style {
    case .primary: Self.primaryFill
    case .warning: Self.warningFill
    case .secondary: Color(.secondarySystemFill)
    case .outline: .clear
    case .teal: .brandTeal
    case .coral: .brandCoral
    case .destructive: .dangerFill
    }
  }
}

extension BadgeView {
  /// The web's `--primary`, near black in the light and a mid grey in the dark.
  fileprivate static var primaryFill: Color {
    Color(
      UIColor {
        $0.userInterfaceStyle == .dark
          ? UIColor(red: 0.441, green: 0.441, blue: 0.459, alpha: 1)
          : UIColor(red: 0.147, green: 0.147, blue: 0.153, alpha: 1)
      })
  }

  /// The web's `--warning`, a dark amber in the light and a light one in the dark.
  fileprivate static var warningFill: Color {
    Color(
      UIColor {
        $0.userInterfaceStyle == .dark
          ? UIColor(red: 0.981, green: 0.716, blue: 0.259, alpha: 1)
          : UIColor(red: 0.518, green: 0.287, blue: 0.022, alpha: 1)
      })
  }

  /// The web's `--warning-foreground`: white on the light's dark amber, near black on the dark's.
  fileprivate static var warningForeground: Color {
    Color(
      UIColor {
        $0.userInterfaceStyle == .dark
          ? UIColor(red: 0.086, green: 0.086, blue: 0.094, alpha: 1)
          : .white
      })
  }
}

extension BadgeView where Icon == EmptyView {
  init(_ text: String, style: Style = .secondary) {
    self.init(text, style: style) { EmptyView() }
  }

  /// A badge as the Kit describes it.
  init(_ badge: Badge) {
    self.init(badge.text, style: badge.style)
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
      BadgeView("Completed", style: .primary)
      BadgeView("Incomplete", style: .warning)
    }
    HStack {
      BadgeView("PADI", style: .outline)
      BadgeView("Expires in 20 days", style: .coral)
      BadgeView("Expired", style: .destructive)
    }
    HStack {
      ForEach(DiveSiteMark.allCases.reversed(), id: \.self) { mark in
        BadgeView(mark.label, style: .outline) { DiveSiteMarkIcon(mark: mark) }
      }
    }
  }
  .padding()
}
