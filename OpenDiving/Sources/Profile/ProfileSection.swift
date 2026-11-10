import OpenDivingKit

/// What the profile shows under its head.
enum ProfileSection: Hashable, CaseIterable {
  case dives, trips, cards, more

  var title: String {
    switch self {
    case .dives: "Dives"
    case .trips: "Trips"
    case .cards: "Cards"
    case .more: "More"
    }
  }

  var icon: Icon {
    switch self {
    case .dives: .dive
    case .trips: .luggage
    case .cards: .idCard
    case .more: .menu
    }
  }
}
