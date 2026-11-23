import Foundation
import Testing

@testable import OpenDivingKit

/// An Ocean's `/Info`, `/Descriptors` and summaries as the probe read them — serials, radio
/// addresses, transmitter ids and positions replaced — and the selection over its logbook.
struct NauticLogbookTests {
  private func captured(_ name: String, _ type: String = "sbem") throws -> Data {
    let url = try #require(
      Bundle.module.url(
        forResource: name, withExtension: type,
        subdirectory: "Fixtures/DiveComputers/ocean-logbook"))
    return try Data(contentsOf: url)
  }

  /// The probe's logbook, newest first: three dives, a run, and twelve more.
  private let ids: [UInt32] = [
    1_793_610_559, 1_793_433_197, 1_793_016_109, 1_792_852_533, 1_792_395_233, 1_792_122_564,
    1_791_792_613, 1_791_705_317, 1_791_697_850, 1_791_607_681, 1_791_292_064, 1_791_283_407,
    1_791_258_518, 1_791_187_562, 1_791_109_042, 1_790_939_992,
  ]
  private let run: UInt32 = 1_792_852_533

  @Test func theDescriptorsNameTheHardware() throws {
    #expect(NauticDescriptors(try captured("descriptors")).hardware == "Seal_RevA3")
    #expect(NauticDescriptors(Data("not descriptors".utf8)).hardware == nil)
  }

  @Test func theInfoNamesTheFirmware() throws {
    #expect(NauticInfo.firmware(try captured("info", "bin")) == 2 << 16 | 51 << 8 | 28)
    #expect(NauticInfo.firmware(Data("Suunto\u{0}2.5\u{0}1.2.300\u{0}".utf8)) == nil)
    #expect(NauticInfo.firmware(Data("Suunto\u{0}1.2.3".utf8)) == nil)
  }

  @Test func theSummariesNameTheirSport() throws {
    let descriptors = NauticDescriptors(try captured("descriptors"))
    for dive in ["1793610559", "1793433197", "1793016109"] {
      #expect(descriptors.sport(inSummary: try captured("summary-\(dive)-scuba")) == 51)
    }
    #expect(descriptors.sport(inSummary: try captured("summary-1792852533-run")) == 3)
    #expect(descriptors.sport(inSummary: Data()) == nil)
    #expect(
      NauticDescriptors(Data()).sport(inSummary: try captured("summary-1792852533-run")) == nil)
  }

  @Test func theSummariesSayHowLongTheEntryLasted() throws {
    let descriptors = NauticDescriptors(try captured("descriptors"))
    let lasted = try ["1793610559-scuba", "1793433197-scuba", "1793016109-scuba", "1792852533-run"]
      .map { descriptors.duration(inSummary: try captured("summary-\($0)")) }
    // Header.Duration is milliseconds, scaled by its `<MOD>x/1000`.
    #expect(lasted == [3675.101, 4334.062, 4966.908, 2178.378])
    #expect(descriptors.duration(inSummary: Data()) == nil)
  }

  /// SBEM records: an id, 16-bit past a byte, a length, the value.
  private func sbem(_ records: [(Int, Data)]) -> Data {
    records.reduce(Data("SBEM0103".utf8)) { bytes, record in
      let id =
        record.0 < 0xFF ? [UInt8(record.0)] : [0xFF, UInt8(record.0 & 0xFF), UInt8(record.0 >> 8)]
      return bytes + Data(id + [UInt8(record.1.count)]) + record.1
    }
  }

  private func descriptor(_ id: UInt16, _ text: String) -> (Int, Data) {
    (0, Data([UInt8(id & 0xFF), UInt8(id >> 8)]) + Data(text.utf8) + Data([0]))
  }

  @Test func aSummaryThatDoesNotFitTheDescriptorsNamesNoSport() throws {
    let fields = [
      descriptor(1, "<PTH>Samples.suunto/sml.Header.ActivityType\n<FRM>int32"),
      descriptor(2, "<PTH>Samples.suunto/sml.Header.Name\n<FRM>utf8"),
      descriptor(3, "<PTH>Samples.suunto/sml.Header.Depth\n<FRM>uint16,precision=2"),
    ]
    let descriptors = NauticDescriptors(sbem(fields + [descriptor(10, "<GRP>2,3,1")]))
    let summary = sbem([(10, Data("Dive\0".utf8) + Data([0x10, 0x00, 61, 0, 0, 0]))])
    #expect(descriptors.sport(inSummary: summary) == 61)

    // Another firmware's layout: a field the record does not hold, one it holds that the group
    // does not name, a record of a group not defined.
    let longer = NauticDescriptors(sbem(fields + [descriptor(10, "<GRP>2,3,3,1")]))
    #expect(longer.sport(inSummary: summary) == nil)
    let shorter = NauticDescriptors(sbem(fields + [descriptor(10, "<GRP>2,1")]))
    #expect(shorter.sport(inSummary: summary) == nil)
    let elsewhere = NauticDescriptors(sbem(fields + [descriptor(11, "<GRP>2,3,1")]))
    #expect(elsewhere.sport(inSummary: summary) == nil)
    // And the probe's summaries against those descriptors.
    #expect(descriptors.sport(inSummary: try captured("summary-1793610559-scuba")) == nil)

    let noSport = NauticDescriptors(sbem(fields + [descriptor(10, "<GRP>2,3,3,3")]))
    #expect(noSport.sport(inSummary: summary) == nil)
  }

  /// The sport's field in a group whose key is past a byte, and a summary cut short of it.
  @Test func aSummaryRecordCanNameItsGroupInSixteenBits() {
    let descriptors = NauticDescriptors(
      sbem([
        descriptor(1, "<PTH>Samples.suunto/sml.Header.ActivityType\n<FRM>int32"),
        descriptor(300, "<GRP>1"),
      ]))
    let summary = sbem([(300, Data([61, 0, 0, 0]))])
    #expect(descriptors.sport(inSummary: summary) == 61)
    #expect(descriptors.sport(inSummary: summary.dropLast()) == nil)
  }

  /// Each scuba summary's start, offset, dive time and max depth, and the run's, which logs no
  /// dive time and so gives its duration.
  @Test func theSummariesSayWhatTheyHoldOfTheDive() throws {
    let descriptors = NauticDescriptors(try captured("descriptors"))
    let expected: [(String, offset: Int, length: Double, depth: Double)] = [
      ("1793610559-scuba", 7200, 3368.873, 19.930),
      ("1793433197-scuba", 7200, 4032.671, 11.243),
      ("1793016109-scuba", 10800, 4644.548, 48.146),
      ("1792852533-run", 10800, 2178.378, 0.008),
    ]
    for (name, offset, length, depth) in expected {
      let id = try #require(UInt32(name.prefix(10)))
      let facts = descriptors.facts(inSummary: try captured("summary-\(name)"), id: id)
      #expect(
        facts.start
          == .instant(Date(timeIntervalSince1970: TimeInterval(id)), offsetSeconds: offset))
      #expect(abs((facts.length ?? 0) - length) < 0.001, "\(name)")
      #expect(abs((facts.maxDepth ?? 0) - depth) < 0.001, "\(name)")
    }
    // A dive the Perdix also recorded: its 15:03:23 at +03:00 is this entry's 15:01:49.
    let shared = descriptors.facts(inSummary: try captured("summary-1793016109-scuba"), id: 1_793_016_109)
    #expect(shared.listedStart == "2026-10-26T15:01:49+03:00")
    // A summary that fits nothing still has the id's start, in no offset.
    let none = descriptors.facts(inSummary: Data(), id: 1_793_016_109)
    #expect(
      none
        == ListedDiveFacts(
          start: .instant(Date(timeIntervalSince1970: 1_793_016_109), offsetSeconds: nil)))
    #expect(none.listedStart == "2026-10-26T12:01:49+00:00")
  }

  @Test func everyEntryIsSummarisedUnlessTheRecordRemembersIt() {
    #expect(NauticSelection.summariesNeeded(ids: ids, remembered: nil) == ids)
    let remembered: [NauticEntrySport] = ids.prefix(4).map {
      NauticEntrySport(id: $0, sport: sport($0).sport, facts: ListedDiveFacts())
    }
    #expect(
      NauticSelection.summariesNeeded(ids: ids, remembered: remembered) == Array(ids.dropFirst(4)))
    // Kept before a summary's facts were read: a dive's entry is read again, the run's is not.
    #expect(
      NauticSelection.summariesNeeded(ids: ids, remembered: ids.prefix(4).map(sport))
        == Array(ids.prefix(3)) + Array(ids.dropFirst(4)))
  }

  /// The probe's sport for an entry: the run's 3, scuba's 51 for every other.
  private func sport(_ id: UInt32) -> NauticEntrySport {
    NauticEntrySport(id: id, sport: id == run ? 3 : 51)
  }

  private func learned(_ ids: some Sequence<UInt32>) -> [UInt32: NauticSelection.Summary] {
    var learned: [UInt32: NauticSelection.Summary] = [:]
    for id in ids { learned[id] = .read(sport: sport(id).sport) }
    return learned
  }

  @Test func withoutAFingerprintEveryEntryIsNewAndTheRunIsSkipped() {
    let selection = NauticSelection(
      ids: ids, fingerprint: nil, remembered: nil, learned: learned(ids))
    #expect(selection.listing.dives == 15)
    #expect(selection.listing.newDives == 15)
    #expect(selection.entries.count == 16)
    #expect(selection.entries.map(\.id) == ids)
    #expect(selection.entries.filter { $0.fate == .skip }.map(\.id) == [run])
    #expect(selection.listing.sports?.count == 16)
    #expect(selection.listing.sports?.first == NauticEntrySport(id: ids[0], sport: 51))
  }

  @Test func aFingerprintMidListTakesTheEntriesBeforeIt() {
    // Remembered from a previous walk, and an entry the record still names that is gone.
    var remembered: [NauticEntrySport] = ids.dropFirst(2).map(sport)
    remembered.append(NauticEntrySport(id: 1_700_000_000, sport: 51))
    let selection = NauticSelection(
      ids: ids, fingerprint: NauticSelection.fingerprint(ids[4]), remembered: remembered,
      learned: learned(ids.prefix(2)))
    #expect(selection.entries.map(\.id) == Array(ids.prefix(4)))
    #expect(selection.entries.map(\.fate) == [.download, .download, .download, .skip])
    let sports: [NauticEntrySport] = ids.map(sport)
    let expected = DiveComputerListing(
      dives: 15, newDives: 3, sports: sports, downloads: downloads(ids.prefix(3)))
    #expect(selection.listing == expected)
  }

  @Test func aFingerprintEqualToNoIdTakesEveryEntry() {
    let selection = NauticSelection(
      ids: ids, fingerprint: NauticSelection.fingerprint(1_700_000_000), remembered: nil,
      learned: learned(ids))
    #expect(selection.entries.count == 16)
    #expect(selection.listing.newDives == 15)
    #expect(NauticSelection.fingerprint(0x6AE5_5893) == Data([0x93, 0x58, 0xE5, 0x6A]))
  }

  /// A new entry whose dive is one the phone need not take again is walked, not downloaded, and
  /// not counted new; a run stays a run whatever the test says.
  @Test func anEntryThePhoneNeedNotTakeAgainIsWalkedButNotCountedNew() {
    let waits: Set<UInt32> = [ids[0], run, ids[6]]
    let selection = NauticSelection(
      ids: ids, fingerprint: NauticSelection.fingerprint(ids[4]), remembered: nil,
      learned: learned(ids)
    ) { waits.contains($0) }
    #expect(selection.entries.map(\.fate) == [.waiting, .download, .download, .skip])
    #expect(selection.entries.map(\.counted) == [true, true, true, false])
    let expected = DiveComputerListing(
      dives: 15, newDives: 2, sports: ids.map(sport), downloads: downloads(ids[1...2]))
    #expect(selection.listing == expected)
  }

  /// The entries a walk downloads, their start the id's and of no known length.
  private func downloads(_ ids: some Sequence<UInt32>) -> [DiveComputerListing.Download] {
    ids.map {
      .init(
        fingerprint: NauticSelection.fingerprint($0),
        facts: ListedDiveFacts(start: start($0)))
    }
  }

  private func start(_ id: UInt32) -> ListedDiveFacts.Start {
    .instant(Date(timeIntervalSince1970: TimeInterval(id)), offsetSeconds: nil)
  }

  /// A summary read this walk stands over what the record kept, and its facts go with the
  /// entry's download and stay with its sport; a remembered entry's facts go with it unread.
  @Test func eachDownloadCarriesWhatItsSummarySaidOfTheDive() {
    let read = ListedDiveFacts(start: start(ids[0]), length: 3368, maxDepth: 19.9)
    let kept = ListedDiveFacts(start: start(ids[1]), length: 4032, maxDepth: 11.2)
    let remembered = [
      NauticEntrySport(id: ids[0], sport: 51, duration: 3000),
      NauticEntrySport(id: ids[1], sport: 51, duration: 4334, facts: kept),
    ]
    var summaries = learned(ids.dropFirst(2).prefix(2))
    summaries[ids[0]] = .read(sport: 51, duration: 3675, facts: read)
    let selection = NauticSelection(
      ids: ids, fingerprint: NauticSelection.fingerprint(ids[4]), remembered: remembered,
      learned: summaries)
    #expect(selection.listing.downloads.map(\.facts).prefix(2) == [read, kept])
    #expect(selection.listing.downloads.map(\.length).prefix(2) == [3368, 4032])
    #expect(
      selection.listing.sports?.prefix(2)
        == [
          NauticEntrySport(id: ids[0], sport: 51, duration: 3675, facts: read),
          NauticEntrySport(id: ids[1], sport: 51, duration: 4334, facts: kept),
        ])
  }

  /// A length a summary gave, this walk's or one the record kept, goes with the entry's download
  /// and stays with its sport. An empty summary's entry, downloaded but not counted, is not one
  /// the time left waits for.
  @Test func eachDownloadCarriesTheLengthItsSummaryGave() {
    let remembered = [NauticEntrySport(id: ids[2], sport: 51, duration: 3000)]
    var summaries = learned(ids.prefix(2))
    summaries[ids[0]] = .read(sport: 51, duration: 3675)
    summaries[ids[1]] = .empty
    summaries[run] = .read(sport: 3, duration: 2178)
    let selection = NauticSelection(
      ids: ids, fingerprint: NauticSelection.fingerprint(ids[4]), remembered: remembered,
      learned: summaries)
    #expect(selection.entries.map(\.fate) == [.download, .download, .download, .skip])
    #expect(
      selection.listing.downloads.map(\.fingerprint)
        == downloads([ids[0], ids[2]]).map(\.fingerprint))
    #expect(selection.listing.downloads.map(\.length) == [3675, 3000])
    #expect(
      selection.listing.sports?.first == NauticEntrySport(id: ids[0], sport: 51, duration: 3675))
    #expect(selection.listing.sports?.contains { $0.id == ids[2] && $0.duration == 3000 } == true)
  }

  @Test func anEntryOfNoKnownSportIsADiveAndAnEmptySummaryIsNone() {
    var summaries = learned(ids)
    summaries[ids[0]] = .read(sport: nil)
    summaries[ids[1]] = .unread
    summaries[ids[2]] = .empty
    summaries[ids[5]] = .empty
    let selection = NauticSelection(
      ids: ids, fingerprint: NauticSelection.fingerprint(ids[4]), remembered: nil,
      learned: summaries)
    #expect(selection.entries.map(\.fate) == [.download, .download, .download, .skip])
    #expect(selection.entries.map(\.counted) == [true, true, false, false])
    #expect(selection.listing.newDives == 2)
    #expect(selection.listing.dives == 13)
    #expect(selection.entries.count == 4)
    // The record keeps what a summary said, a sport or none, and nothing of an empty or
    // unread one.
    let kept = selection.listing.sports ?? []
    #expect(kept.first == NauticEntrySport(id: ids[0], sport: nil))
    #expect(!kept.contains { [ids[1], ids[2], ids[5]].contains($0.id) })
    #expect(kept.count == 13)
    // An entry this walk did not summarise and the record does not name counts as unread.
    #expect(
      NauticSelection(ids: ids, fingerprint: nil, remembered: nil, learned: [:])
        .listing.dives == 16)
  }
}

