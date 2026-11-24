import Foundation
import Testing

@testable import OpenDivingKit

/// What the question says beneath it and what the list draws, for each mix of the dives the
/// logbook lacks and those it holds without the computer's original download.
struct DownloadChoiceTests {
  /// `count` dives of the given fingerprint base, each 20 minutes long.
  private func dives(_ count: Int, from base: UInt8) -> [DiveComputerListing.Download] {
    (0..<count).map {
      .init(fingerprint: DiveComputerFixtures.fingerprint(base + UInt8($0)), length: 1200)
    }
  }

  /// At the Nautic family's first pace, a minute of transfer for each 20-minute dive.
  private func choice(
    notInLogbook: Int, toUpdate: Int, checked: Bool = true, pace: DownloadPace? = .nauticFirst
  ) -> DownloadChoice {
    DownloadChoice(
      stage: .question, notInLogbook: dives(notInLogbook, from: 0x10),
      toUpdate: dives(toUpdate, from: 0x40), checked: checked, computer: "Suunto Ocean",
      watchZone: nil, pace: pace)
  }

  @Test func theLineCountsEachKindItHolds() {
    #expect(
      choice(notInLogbook: 12, toUpdate: 0).questionDetail
        == "12 dives on this computer are not in your logbook. Downloading them takes about 12"
        + " minutes.")
    #expect(
      choice(notInLogbook: 12, toUpdate: 3).questionDetail
        == "12 dives on this computer are not in your logbook. 3 dives in your logbook can be"
        + " updated with data from this computer. Downloading them takes about 15 minutes.")
    #expect(
      choice(notInLogbook: 0, toUpdate: 12).questionDetail
        == "12 dives in your logbook can be updated with data from this computer. Downloading"
        + " them takes about 12 minutes.")
  }

  /// *it* only where the question counts one dive in all.
  @Test func theLineIsSingularForOneDive() {
    #expect(
      choice(notInLogbook: 0, toUpdate: 1).questionDetail
        == "1 dive in your logbook can be updated with data from this computer. Downloading it"
        + " takes about 1 minute.")
    #expect(
      choice(notInLogbook: 1, toUpdate: 1).questionDetail
        == "1 dive on this computer is not in your logbook. 1 dive in your logbook can be updated"
        + " with data from this computer. Downloading them takes about 2 minutes.")
    #expect(
      choice(notInLogbook: 1, toUpdate: 0, pace: nil).questionDetail
        == "1 dive on this computer is not in your logbook.")
  }

  @Test func anUncheckedLogbookIsCountedAsTheComputersDives() {
    #expect(
      choice(notInLogbook: 2, toUpdate: 0, checked: false, pace: nil).questionDetail
        == "2 dives on this computer.")
  }

  /// Each kind is a section of its own, the dives to update after, and a kind with no dive draws
  /// none; the dives offered, which *Download all N dives* and the chosen count read, are both.
  @Test func eachKindIsASectionShownOnlyWithADive() {
    let both = choice(notInLogbook: 2, toUpdate: 1)
    let sections = both.sections(chosen: [DiveComputerFixtures.fingerprint(0x40)], units: .metric)
    #expect(sections.map(\.id) == [.notInLogbook, .toUpdate])
    #expect(sections.map(\.heading) == ["Dives not in your logbook", "Dives to update"])
    #expect(
      sections.map(\.line)
        == [
          nil,
          "These dives are already in your logbook. Downloading them adds data from this"
            + " computer. No new dives are made.",
        ])
    #expect(sections.map { $0.rows.map(\.chosen) } == [[false, false], [true]])
    #expect(both.dives.count == 3)
    #expect(
      both.dives(in: [
        DiveComputerFixtures.fingerprint(0x40), DiveComputerFixtures.fingerprint(0x10),
      ])
      .map(\.fingerprint)
        == [DiveComputerFixtures.fingerprint(0x10), DiveComputerFixtures.fingerprint(0x40)])

    #expect(
      choice(notInLogbook: 0, toUpdate: 2).sections(chosen: [], units: .metric).map(\.id) == [
        .toUpdate
      ])
    #expect(
      choice(notInLogbook: 2, toUpdate: 0).sections(chosen: [], units: .metric).map(\.id) == [
        .notInLogbook
      ])
    #expect(
      choice(notInLogbook: 1, toUpdate: 0, checked: false).sections(chosen: [], units: .metric)
        .map(\.heading) == ["Dives on this computer"])
  }
}
