/// What a gear item's page shows under its head.
nonisolated enum GearItemSection: TabSection {
  case service, dives

  var title: String {
    switch self {
    case .service: "Service"
    case .dives: "Dives"
    }
  }
}
