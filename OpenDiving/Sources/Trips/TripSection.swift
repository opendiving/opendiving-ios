/// What a trip's page shows under its head.
nonisolated enum TripSection: TabSection {
  case info, dives, marineLife

  var title: String {
    switch self {
    case .info: "Info"
    case .dives: "Dives"
    case .marineLife: "Marine life"
    }
  }
}
