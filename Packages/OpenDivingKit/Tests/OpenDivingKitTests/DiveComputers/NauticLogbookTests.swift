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

  /// SBEM records: an id, a length, the value.
  private func sbem(_ records: [(UInt8, Data)]) -> Data {
    records.reduce(Data("SBEM0103".utf8)) { bytes, record in
      bytes + Data([record.0, UInt8(record.1.count)]) + record.1
    }
  }

  private func descriptor(_ id: UInt16, _ text: String) -> (UInt8, Data) {
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

  @Test func everyEntryIsSummarisedUnlessTheRecordRemembersIt() {
    #expect(NauticSelection.summariesNeeded(ids: ids, remembered: nil) == ids)
    let remembered: [NauticEntrySport] = ids.prefix(4).map(sport)
    #expect(
      NauticSelection.summariesNeeded(ids: ids, remembered: remembered) == Array(ids.dropFirst(4)))
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
    #expect(selection.listing.newEntries == 16)
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
    let expected = DiveComputerListing(dives: 15, newDives: 3, newEntries: 4, sports: sports)
    #expect(selection.listing == expected)
  }

  @Test func aFingerprintEqualToNoIdTakesEveryEntry() {
    let selection = NauticSelection(
      ids: ids, fingerprint: NauticSelection.fingerprint(1_700_000_000), remembered: nil,
      learned: learned(ids))
    #expect(selection.listing.newEntries == 16)
    #expect(selection.listing.newDives == 15)
    #expect(NauticSelection.fingerprint(0x6AE5_5893) == Data([0x93, 0x58, 0xE5, 0x6A]))
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
    #expect(selection.listing.newDives == 2)
    #expect(selection.listing.dives == 13)
    #expect(selection.listing.newEntries == 4)
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
