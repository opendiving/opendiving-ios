/// What a species' page shows under its head.
nonisolated enum SpeciesSection: TabSection {
  case dives, diveSites, taxonomy

  var title: String {
    switch self {
    case .dives: "Dives"
    case .diveSites: "Dive Sites"
    case .taxonomy: "Taxonomy"
    }
  }
}
