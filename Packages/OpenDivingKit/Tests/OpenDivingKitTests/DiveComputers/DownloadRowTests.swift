import Foundation
import Testing

@testable import OpenDivingKit

struct DownloadRowTests {
  private let utc = TimeZone(secondsFromGMT: 0)!

  private func clock(_ text: String) -> LocalDateTime {
    DiveTimestamp(wireValue: text)!.wallClock!
  }

  private func listed(
    _ byte: UInt8, start: String?, inTransfer: Bool = false, uuid: UUID? = nil
  ) -> DownloadRow.Listed {
    DownloadRow.Listed(
      uuid: uuid, fingerprint: Data([byte]), computer: "Shearwater Perdix 3",
      facts: ListedDiveFacts(start: start.map { .wallClock(clock($0)) }), watchZone: nil,
      inTransfer: inTransfer)
  }

  private func onPhone(
    _ wait: DiveOnPhone.Wait, start: String? = nil, archive: UUID? = UUID()
  ) -> DiveOnPhone {
    DiveOnPhone(
      id: UUID(), computer: "Suunto Ocean",
      facts: start.map { ListedDiveFacts(start: .wallClock(clock($0))) }, watchZone: nil,
      wait: wait, archive: archive)
  }

  @Test func eachWaitReadsItsLine() {
    let lines: [(DiveOnPhone.Wait, String)] = [
      (.nothing, "Syncing"), (.walkEnd, "Syncing"), (.retry, "Syncing"),
      (.route, "Waiting for internet"), (.signIn, "Waiting for sign-in"),
      (.timeZone, "Waiting for your answer"), (.order, "Waiting for your answer"),
      (.refused, "Could not import"),
    ]
    for (wait, text) in lines {
      #expect(DownloadRow.Line(wait).text == text)
    }
  }

  @Test func theDiveBeingReadIsSyncingAndTheRestWait() {
    let rows = DownloadRow.rows(
      onComputer: [
        listed(1, start: "2026-10-26T15:03:23", inTransfer: true),
        listed(2, start: "2026-10-25T09:00:00"),
      ],
      onPhone: [], units: .metric, phoneZone: utc)
    #expect(rows.map(\.line) == [.syncing, .waiting])
    #expect(rows.map(\.opens) == [.diveComputers, .diveComputers])
  }

  /// A row of the walk in flight, or one a question holds, opens *Dive Computers*; an archive's
  /// opens *Waiting to Sync*.
  @Test func aRowOpensWhereTheDiverCanAct() {
    let rows = DownloadRow.rows(
      onComputer: [],
      onPhone: [
        onPhone(.route, start: "2026-10-05T10:00:00"),
        onPhone(.refused, start: "2026-10-04T10:00:00"),
        onPhone(.order, start: "2026-10-03T10:00:00"),
        onPhone(.timeZone, start: "2026-10-02T10:00:00", archive: nil),
        onPhone(.nothing, start: "2026-10-01T10:00:00", archive: nil),
      ],
      units: .metric, phoneZone: utc)
    #expect(
      rows.map(\.opens) == [
        .waitingToSync, .waitingToSync, .diveComputers, .diveComputers, .diveComputers,
      ])
  }

  /// Newest first by the start shown, the walk's dives among the phone's; a dive with no start
  /// after them, in the order given.
  @Test func newestFirstWithTheUndatedLast() {
    let undatedArchive = onPhone(.route)
    let rows = DownloadRow.rows(
      onComputer: [listed(1, start: "2026-10-20T08:00:00"), listed(2, start: nil)],
      onPhone: [
        undatedArchive, onPhone(.route, start: "2026-10-10T08:00:00"),
        onPhone(.nothing, start: "2026-10-22T08:00:00", archive: nil),
      ],
      units: .metric, phoneZone: utc)
    #expect(
      rows.map { $0.card.facts.first?.text }
        == [
          "Oct 22, 2026, 08:00", "Oct 20, 2026, 08:00", "Oct 10, 2026, 08:00", "Waiting",
          "Waiting for internet",
        ])
    #expect(rows[3].id == Hex.lowercase([2]))
    #expect(rows[4].id == undatedArchive.id.uuidString)
  }

  /// The queue still lists a dive the phone holds only between the dive being kept and the walk
  /// noting it taken: one row, the queue's.
  @Test func oneRowForADiveTheQueueAndThePhoneBothHold() {
    let uuid = UUID()
    let rows = DownloadRow.rows(
      onComputer: [listed(1, start: "2026-10-20T08:00:00", inTransfer: true, uuid: uuid)],
      onPhone: [
        DiveOnPhone(
          id: uuid, computer: "Shearwater Perdix 3", facts: nil, watchZone: nil, wait: .route,
          archive: nil)
      ],
      units: .metric, phoneZone: utc)
    #expect(rows.map(\.id) == [uuid.uuidString])
    #expect(rows.map(\.line) == [.syncing])
  }

  @Test func theCardShowsTheFactsInTheDiversUnits() {
    let facts = ListedDiveFacts(
      start: .wallClock(clock("2026-10-26T15:03:23")), length: 4577, maxDepth: 47.7)
    let dive = DiveOnPhone(
      id: UUID(), computer: "Shearwater Perdix 3", facts: facts, watchZone: nil, wait: .signIn,
      archive: UUID())
    let metric = DownloadRow.rows(onComputer: [], onPhone: [dive], units: .metric).first?.card
    #expect(metric?.title == "Shearwater Perdix 3")
    #expect(metric?.facts.map(\.text) == ["Oct 26, 2026, 15:03", "Waiting for sign-in"])
    #expect(
      metric?.figures == [
        Figure(label: "Dive time", value: "76min"), Figure(label: "Max depth", value: "48 m"),
      ])
    let imperial = DownloadRow.rows(onComputer: [], onPhone: [dive], units: .imperial).first?.card
    #expect(imperial?.figures.last == Figure(label: "Max depth", value: "156 ft"))
  }

  @Test func whatTheListDidNotSayIsADash() {
    let card = DiveCardContent.download(
      computer: "Suunto Ocean", start: nil, facts: nil, line: .waiting, units: .metric)
    #expect(card.facts.map(\.text) == ["Waiting"])
    #expect(card.figures.map(\.value) == [nil, nil])
  }

  /// An instant with no offset is shown on the watch's clock, else the phone's.
  @Test func anInstantIsShownOnTheWatchsClock() throws {
    let instant = try #require(DiveTimestamp(wireValue: "2026-10-26T12:00:00+00:00")?.instant)
    let dive = DiveOnPhone(
      id: UUID(), computer: "Suunto Ocean",
      facts: ListedDiveFacts(start: .instant(instant, offsetSeconds: nil)),
      watchZone: TimeZone(secondsFromGMT: 3 * 3600), wait: .nothing, archive: nil)
    let rows = DownloadRow.rows(onComputer: [], onPhone: [dive], units: .metric, phoneZone: utc)
    #expect(rows.first?.card.facts.first?.text == "Oct 26, 2026, 15:00")
  }
}
