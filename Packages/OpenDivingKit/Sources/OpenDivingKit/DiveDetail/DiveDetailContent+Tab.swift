extension DiveDetailContent {
  /// The page's tabs, in order. Info holds the environment, training, location, people and notes;
  /// Data the profile, tanks, gas consumption, exposure and recordings.
  public enum Tab: CaseIterable, Hashable, Sendable {
    case info, data, gear, aquaticLife
  }

  /// Whether `tab` has a section to draw; a tab with none says so instead.
  public func hasSections(in tab: Tab) -> Bool {
    switch tab {
    case .info:
      !environment.isEmpty || course != nil || location != nil || !people.isEmpty || notes != nil
    case .data:
      profile != nil || tanks != nil || gasConsumption != nil || exposure != nil
        || !recordings.isEmpty
    case .gear: gear != nil
    case .aquaticLife: !sightings.isEmpty
    }
  }
}
