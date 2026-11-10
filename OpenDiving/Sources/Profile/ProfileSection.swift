/// What the profile shows under its head.
nonisolated enum ProfileSection: TabSection {
  case dives, trips, cards, more

  var title: String {
    switch self {
    case .dives: "Dives"
    case .trips: "Trips"
    case .cards: "Cards"
    case .more: "More"
    }
  }
}
