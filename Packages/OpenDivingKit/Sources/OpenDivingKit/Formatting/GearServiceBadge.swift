extension GearServiceStatus {
  /// The badge's colour (`serviceStatusBadgeVariant`), the scale read by hue: teal settled, the
  /// brand's coral due soon, destructive overdue.
  public var badgeStyle: Badge.Style {
    switch self {
    case .overdue: .destructive
    case .dueSoon: .coral
    case .ok: .teal
    }
  }

  /// The status as the gear list's badge draws it.
  public var badge: Badge { Badge(label, style: badgeStyle) }
}
