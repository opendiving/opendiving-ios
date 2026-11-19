/// What an opened site's panel shows under its head.
nonisolated enum SiteSection: TabSection {
  case info, aquaticLife, myDives

  var title: String {
    switch self {
    case .info: "Info"
    case .aquaticLife: "Aquatic life"
    case .myDives: "My dives"
    }
  }
}
