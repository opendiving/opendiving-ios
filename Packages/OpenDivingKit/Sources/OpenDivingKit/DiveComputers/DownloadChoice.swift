import Foundation

/// What a walk the diver watches asks before its first transfer, holding the link while it
/// waits: *Which dives do you want to download?* for a computer that awaits its question, then,
/// where the diver chooses, the list; or the list alone, from *Choose dives to download*. Both
/// offer the dives the logbook lacks and those it holds without the computer's original download.
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

  /// One of the list's sections: the dives the logbook lacks, or those to update.
  public struct Section: Hashable, Sendable, Identifiable {
    public enum Kind: Hashable, Sendable {
      case notInLogbook, toUpdate
    }

    public let id: Kind
    public let heading: String
    /// Beneath the heading, where the section says more of its dives.
    public let line: String?
    public let rows: [Row]
  }

  public internal(set) var stage: Stage
  /// The computer's dives that the logbook does not hold and the phone does not keep, newest
  /// first, each with what the computer's list said of it.
  public let notInLogbook: [DiveComputerListing.Download]
  /// The computer's dives that the logbook holds without the computer's original download and
  /// the phone neither keeps nor has sent for it, newest first.
  public let toUpdate: [DiveComputerListing.Download]
  /// The server answered which of the computer's dives the logbook holds; without its answer,
  /// ``notInLogbook`` may hold some it does, and ``toUpdate`` is empty.
  public let checked: Bool
  /// *Shearwater Perdix 3*.
  public let computer: String
  /// The zone the watch reported, for showing an instant with no offset.
  public let watchZone: TimeZone?
  /// What a download of the dives is reckoned at: the computer's pace, else its family's first.
  let pace: DownloadPace?

  /// Every dive offered: those the logbook lacks, then those to update.
  public var dives: [DiveComputerListing.Download] { notInLogbook + toUpdate }

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

  /// Beneath the question: how many dives the logbook lacks, then how many it holds that can be
  /// updated, each where there are any, and about how long they would all take where the pace
  /// says.
  public var questionDetail: String {
    var sentences: [String] = []
    if !checked {
      sentences.append(DiveComputerText.onComputerUnchecked(notInLogbook.count))
    } else if !notInLogbook.isEmpty || toUpdate.isEmpty {
      sentences.append(DiveComputerText.notInLogbook(notInLogbook.count))
    }
    if !toUpdate.isEmpty {
      sentences.append(DiveComputerText.canBeUpdated(toUpdate.count))
    }
    if let seconds = time(of: dives) {
      sentences.append(DiveComputerText.downloadTakes(seconds, dives: dives.count))
    }
    return sentences.joined(separator: " ")
  }

  /// The dives offered that are in `chosen`, in the list's order.
  public func dives(in chosen: Set<Data>) -> [DiveComputerListing.Download] {
    dives.filter { chosen.contains($0.fingerprint) }
  }

  /// The list's sections, each shown only where it holds a dive: *Dives not in your logbook*,
  /// then *Dives to update*, each newest first as the computer lists them, every row the dive's
  /// card with its start, length and max depth, and whether it is in `chosen`.
  public func sections(chosen: Set<Data>, units: UnitSystem, phoneZone: TimeZone = .current)
    -> [Section]
  {
    func rows(_ dives: [DiveComputerListing.Download]) -> [Row] {
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
    var sections: [Section] = []
    if !notInLogbook.isEmpty {
      sections.append(
        Section(
          id: .notInLogbook,
          heading: checked
            ? DiveComputerText.notInLogbookHeading : DiveComputerText.onComputerHeading,
          line: nil, rows: rows(notInLogbook)))
    }
    if !toUpdate.isEmpty {
      sections.append(
        Section(
          id: .toUpdate, heading: DiveComputerText.toUpdateHeading,
          line: DiveComputerText.toUpdateLine, rows: rows(toUpdate)))
    }
    return sections
  }
}
