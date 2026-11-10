import OpenDivingKit

/// What an opened site's panel shows under its head.
nonisolated enum SiteSection: TabSection {
  case info, marineLife, myDives

  var title: String {
    switch self {
    case .info: "Info"
    case .marineLife: "Marine life"
    case .myDives: "My dives"
    }
  }

  var icon: Icon {
    switch self {
    case .info: .info
    case .marineLife: .fish
    case .myDives: .dive
    }
  }
}
