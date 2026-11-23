import Foundation

/// What a walk the diver watches asks before its first transfer, holding the link while it
/// waits: *Which dives do you want to download?* for a computer that awaits its question, then,
/// where the diver chooses, the list; or the list alone, from *Choose dives to download*.
public struct DownloadChoice: Hashable, Sendable {
  public enum Stage: Hashable, Sendable {
    case question, list
  }

  /// One dive of the list, as its row draws it.
  public struct Row: Hashable, Sendable, Identifiable {
    /// The fingerprint's hex.
    public let id: String
    public let fingerprint: Data
    public let card: DiveCardContent
    public let chosen: Bool
  }

  public internal(set) var stage: Stage
  /// The computer's dives that the logbook does not hold and the phone does not keep, newest
  /// first, each with what the computer's list said of it.
  public let dives: [DiveComputerListing.Download]
  /// The server answered which of the computer's dives the logbook holds; without its answer,
  /// ``dives`` may hold some it does.
  public let checked: Bool
  /// *Shearwater Perdix 3*.
  public let computer: String
  /// The zone the watch reported, for showing an instant with no offset.
  public let watchZone: TimeZone?
  /// What a download of the dives is reckoned at: the computer's pace, else its family's first.
  let pace: DownloadPace?

  /// The seconds downloading `dives` would take, nil where the pace does not say for every one of
  /// them.
  public func time(of dives: [DiveComputerListing.Download]) -> TimeInterval? {
    guard let pace, !dives.isEmpty else { return nil }
    var total: TimeInterval = 0
    for dive in dives {
      let byLength = dive.length.flatMap { length in pace.perDiveSecond.map { length * $0 } }
      guard let cost = byLength ?? pace.perDive else { return nil }
      total += cost
    }
    return total
  }

  /// The dives of the list that are in `chosen`, in the list's order.
  public func dives(in chosen: Set<Data>) -> [DiveComputerListing.Download] {
    dives.filter { chosen.contains($0.fingerprint) }
  }

  /// The list's rows, newest first as the computer lists them: each dive's card with its start,
  /// length and max depth, and whether it is in `chosen`.
  public func rows(chosen: Set<Data>, units: UnitSystem, phoneZone: TimeZone = .current) -> [Row] {
    dives.map { dive in
      Row(
        id: Hex.lowercase(dive.fingerprint), fingerprint: dive.fingerprint,
        card: .download(
          computer: computer,
          start: dive.facts.shownStart(watchZone: watchZone, phoneZone: phoneZone),
          facts: dive.facts, line: nil, units: units),
        chosen: chosen.contains(dive.fingerprint))
    }
  }
}
