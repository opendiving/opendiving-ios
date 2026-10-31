import Foundation
import Testing

@testable import OpenDivingKit

/// The sport of a Nautic logbook entry, over SBEM streams built by hand.
struct NauticSportTests {
  private static let magic = Array("SBEM0103".utf8)

  /// One TLV record, its length in the four-byte form where `long`.
  private func record(_ id: UInt8, _ value: [UInt8], long: Bool = false) -> [UInt8] {
    guard long else { return [id, UInt8(value.count)] + value }
    let count = UInt32(value.count)
    return [id, 255] + (0..<4).map { UInt8(truncatingIfNeeded: count >> (8 * $0)) } + value
  }

  /// The activity record: a zero time delta, the sport id, the mode id as Suunto writes it.
  private func activity(_ sport: UInt8) -> [UInt8] {
    record(0x08, [0, 0, sport] + Array(String(sport).utf8) + [0])
  }

  private func stream(_ records: [UInt8]...) -> Data {
    Data(Self.magic + records.joined())
  }

  private let timeline: [UInt8] = [0x01, 0x08, 0xC2, 0xA6, 0x66, 0xFC, 0xA0, 0x01, 0x00, 0x0C]

  @Test func scubaIsADiveAndARunIsNot() {
    let scuba = stream(timeline, record(0x02, [0, 0, 0, 0]), activity(51))
    let run = stream(timeline, activity(3))
    #expect(NauticSport.id(in: scuba) == 51)
    #expect(NauticSport.isDive(scuba))
    #expect(NauticSport.id(in: run) == 3)
    #expect(!NauticSport.isDive(run))
    #expect(NauticSport.isDive(stream(activity(61))))
    #expect(NauticSport.isDive(stream(activity(62))))
  }

  /// No activity record, or no SBEM at all, is read as a dive: one skipped is lost for good.
  @Test func anEntryNamingNoSportIsADive() {
    #expect(NauticSport.id(in: stream(timeline, record(0x02, [0, 0, 0, 0]))) == nil)
    #expect(NauticSport.isDive(stream(timeline)))
    #expect(NauticSport.isDive(Data("perdix dive 3".utf8)))
    #expect(NauticSport.isDive(Data()))
    // An activity record whose mode id is not NUL-terminated ASCII is no activity record.
    #expect(NauticSport.isDive(stream(record(0x08, [0, 0, 3, 0xFF, 0x01]))))
  }

  @Test func theWalkReadsLongRecordsAndStepsPastArtefacts() {
    let long = record(0x22, [UInt8](repeating: 0x08, count: 300), long: true)
    #expect(NauticSport.id(in: stream(timeline, long, activity(3))) == 3)
    // A GPS header whose length is not a GPS fix's is stepped past a byte at a time, and the
    // walk finds the records after it.
    #expect(NauticSport.id(in: stream(timeline, [0x0B, 0x02], activity(3))) == 3)
  }

  /// Only the profile is read: an activity record in the appended summary is not the entry's.
  @Test func theSummarySectionIsNotRead() {
    let summary = Self.magic + activity(3)
    #expect(NauticSport.id(in: stream(timeline) + Data(summary)) == nil)
    #expect(NauticSport.id(in: stream(timeline, activity(51)) + Data(summary)) == 51)
  }
}
