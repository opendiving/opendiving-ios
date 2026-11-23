import Foundation
import Testing

@testable import OpenDivingKit

/// A walk's time left: from the pace kept by earlier walks until a dive of its own is timed, then
/// from its own; by length where the computer gave one, per dive where it did not; from
/// libdivecomputer's progress where the family reports it.
struct DownloadEstimateTests {
  private let start = DiveComputerFixtures.moment

  private func at(_ seconds: TimeInterval) -> Date { start.addingTimeInterval(seconds) }

  private func mark(_ byte: UInt8) -> Data { Data([byte, 0, 0, 0]) }

  /// Three dives of an hour, half an hour and an hour.
  private var listing: DiveComputerListing {
    DiveComputerListing(
      dives: 3, newDives: 3,
      downloads: [
        .init(fingerprint: mark(1), length: 3600), .init(fingerprint: mark(2), length: 1800),
        .init(fingerprint: mark(3), length: 3600),
      ])
  }

  @Test func withNothingKeptAndNothingTimedThereIsNoEstimate() {
    var estimate = DownloadEstimate()
    #expect(estimate.remaining(at: start) == nil)
    #expect(!estimate.hasLeft)
    estimate.listed(listing, at: start)
    #expect(estimate.remaining(at: at(10)) == nil)
    #expect(estimate.hasLeft)
    for byte: UInt8 in 1...3 { estimate.delivered(mark(byte), at: at(10)) }
    #expect(!estimate.hasLeft)
  }

  @Test func theKeptPaceGivesAnEstimateBeforeTheFirstDive() {
    var estimate = DownloadEstimate(kept: DownloadPace(perDiveSecond: 0.05, perDive: 200))
    estimate.listed(listing, at: start)
    #expect(estimate.remaining(at: start) == 450)
    // The dive in flight costs what is left of its share, and never less than nothing.
    #expect(estimate.remaining(at: at(100)) == 350)
    #expect(estimate.remaining(at: at(500)) == 270)
  }

  @Test func theWalksOwnPaceTakesOverOnceADiveIsTimed() {
    var estimate = DownloadEstimate(kept: DownloadPace(perDiveSecond: 0.05, perDive: 200))
    estimate.listed(listing, at: start)
    estimate.delivered(mark(1), at: at(360))
    #expect(estimate.measured == DownloadPace(perDiveSecond: 0.1, perDive: 360))
    #expect(estimate.remaining(at: at(360)) == 540)
    estimate.delivered(mark(2), at: at(540))
    #expect(estimate.remaining(at: at(600)) == 300)
    estimate.delivered(mark(3), at: at(900))
    #expect(estimate.remaining(at: at(900)) == nil)
  }

  @Test func aDiveOfNoKnownLengthCostsThePacePerDive() {
    var estimate = DownloadEstimate(kept: DownloadPace(perDiveSecond: 0.05))
    estimate.listed(
      DiveComputerListing(
        dives: 2, newDives: 2,
        downloads: [
          .init(fingerprint: mark(1), length: 3600), .init(fingerprint: mark(2), length: nil),
        ]),
      at: start)
    // Without a pace per dive, a dive of no length has no cost to give.
    #expect(estimate.remaining(at: start) == nil)
    estimate.delivered(mark(1), at: at(150))
    #expect(estimate.remaining(at: at(150)) == 150)
  }

  @Test func aSkipMovesOnWithoutTimingAndAnInterruptionIsNotTimed() {
    var estimate = DownloadEstimate()
    estimate.listed(listing, at: start)
    estimate.skipped(mark(1), at: at(5))
    estimate.interrupt()
    estimate.delivered(mark(2), at: at(600))
    #expect(estimate.measured == nil)
    estimate.delivered(mark(3), at: at(900))
    #expect(estimate.measured == DownloadPace(perDiveSecond: 300.0 / 3600, perDive: 300))
  }

  @Test func whileInterruptedTheDiveInFlightIsNotCountedDown() {
    var estimate = DownloadEstimate(kept: DownloadPace(perDiveSecond: 0.1))
    estimate.listed(listing, at: start)
    estimate.interrupt()
    #expect(estimate.remaining(at: at(300)) == 900)
  }

  @Test func progressIsReckonedFromTheRateItMovedAt() {
    var estimate = DownloadEstimate(kept: DownloadPace(perDiveSecond: 0.1))
    estimate.progressed(0.25, at: start)
    #expect(estimate.remaining(at: start) == nil)
    #expect(estimate.hasLeft)
    estimate.progressed(0.5, at: at(60))
    #expect(estimate.remaining(at: at(60)) == 120)
    #expect(estimate.remaining(at: at(100)) == 80)
    #expect(estimate.remaining(at: at(1000)) == 0)
  }

  @Test func aLaterWalksPaceIsAveragedIntoTheKeptOne() {
    let kept = DownloadPace(perDiveSecond: 0.1, perDive: 300)
    #expect(
      kept.merged(DownloadPace(perDiveSecond: 0.3, perDive: nil))
        == DownloadPace(perDiveSecond: 0.2, perDive: 300))
    #expect(DownloadPace().merged(kept) == kept)
  }

  @Test func theTimeLeftReadsInMinutesAndHours() {
    #expect(DiveComputerText.timeLeft(0) == "Less than a minute left")
    #expect(DiveComputerText.timeLeft(59) == "Less than a minute left")
    #expect(DiveComputerText.timeLeft(60) == "About 1 minute left")
    #expect(DiveComputerText.timeLeft(269) == "About 4 minutes left")
    #expect(DiveComputerText.timeLeft(3600) == "About 1 hour left")
    #expect(DiveComputerText.timeLeft(4210) == "About 1 hour 10 minutes left")
    #expect(DiveComputerText.timeLeft(7300) == "About 2 hours 2 minutes left")
    #expect(DiveComputerText.chosenTakes(30) == "Less than a minute to download")
    #expect(
      DiveComputerText.downloadTakes(4210, dives: 12)
        == "Downloading them takes about 1 hour 10 minutes.")
    #expect(DiveComputerText.downloadTakes(60, dives: 1) == "Downloading it takes about 1 minute.")
  }
}
