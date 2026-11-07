import Foundation
import Testing

@testable import OpenDivingKit

/// The SBEM record walk, over streams built by hand.
struct SBEMRecordsTests {
  private func walk(_ records: [UInt8]...) throws -> SBEMRecords {
    try #require(SBEMRecords(SBEMRecords.magic + records.joined()))
  }

  private func all(_ walk: inout SBEMRecords) -> [(id: Int, value: [UInt8])] {
    var records: [(id: Int, value: [UInt8])] = []
    while let record = walk.next() { records.append((record.id, Array(record.value))) }
    return records
  }

  @Test func theIdAndTheLengthEachEscapeOn0xFF() throws {
    let long = [UInt8](repeating: 7, count: 300)
    var records = try walk(
      [0x08, 0x01, 0xAA],
      [0xFF, 0x34, 0x12, 0x01, 0xBB],
      [0x02, 0xFF, 0x2C, 0x01, 0x00, 0x00] + long,
      [0xFF, 0xFF, 0xFF, 0xFF, 0x01, 0x00, 0x00, 0x00, 0xCC])
    let read = all(&records)
    #expect(read.map(\.id) == [0x08, 0x1234, 0x02, 0xFFFF])
    #expect(read.map(\.value) == [[0xAA], [0xBB], long, [0xCC]])
    #expect(records.isComplete)
  }

  @Test func aStreamOfNoRecordsIsComplete() throws {
    var records = try walk()
    #expect(records.next() == nil)
    #expect(records.isComplete)
  }

  @Test func bytesWithoutTheMagicAreNoWalk() {
    #expect(SBEMRecords(Data()) == nil)
    #expect(SBEMRecords(Data("SBEM0104".utf8)) == nil)
  }

  /// A stream cut anywhere keeps the records before the cut, and is complete only where the cut
  /// falls between two of them.
  @Test func aTruncatedStreamEndsAtTheLastWholeRecord() throws {
    let first: [UInt8] = [0xFF, 0x34, 0x12, 0x01, 0xBB]
    let second: [UInt8] = [0x02, 0xFF, 0x02, 0x00, 0x00, 0x00, 0xAA, 0xBB]
    let stream = first + second
    for cut in 0...stream.count {
      var records = try walk(Array(stream[..<cut]))
      let expected = cut == stream.count ? 2 : cut >= first.count ? 1 : 0
      #expect(all(&records).count == expected)
      #expect(records.isComplete == [0, first.count, stream.count].contains(cut))
      // The walk stays ended.
      #expect(records.next() == nil)
    }
  }

  @Test func aLengthPastTheStreamEndsTheWalk() throws {
    var records = try walk([0x01, 0x01, 0xAA], [0x02, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xBB])
    #expect(all(&records).map(\.id) == [0x01])
    #expect(!records.isComplete)
  }

  /// Index arithmetic holds on a slice, which starts at its own offset in the parent's bytes.
  @Test func aSliceWalksFromItsOwnStart() throws {
    let bytes = Data([0xEE, 0xEE]) + SBEMRecords.magic + [0x01, 0x01, 0xAA, 0xEE]
    var records = try #require(SBEMRecords(bytes[2..<(bytes.endIndex - 1)]))
    #expect(all(&records).map(\.value) == [[0xAA]])
    #expect(records.isComplete)
  }
}
