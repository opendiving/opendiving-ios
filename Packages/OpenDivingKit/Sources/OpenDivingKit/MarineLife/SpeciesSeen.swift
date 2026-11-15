/// A record's *Marine life* tab: the species seen on its dives, read whole.
public enum SpeciesSeen: Hashable, Sendable {
  /// The record counts no species, so nothing is asked for and the tab says none were seen.
  case none
  case loading
  case loaded([SpeciesLifeListEntry])
  case failed
}
