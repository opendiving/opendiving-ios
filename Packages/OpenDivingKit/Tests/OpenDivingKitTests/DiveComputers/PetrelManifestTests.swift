import Foundation
import Testing

@testable import OpenDivingKit

/// The Perdix 3's dive index and identifier answers as the probe read them, its serial replaced,
/// and synthetic pages for what one computer's index does not show.
struct PetrelManifestTests {
  private func probePage() throws -> Data {
    let url = try #require(
      Bundle.module.url(
        forResource: "perdix-3-manifest", withExtension: "bin",
        subdirectory: "Fixtures/DiveComputers"))
    return try Data(contentsOf: url)
  }

  private func start(_ value: UInt32) -> Data {
    Data((0..<4).reversed().map { UInt8(truncatingIfNeeded: value >> (8 * $0)) })
  }

  /// A record: its marker, its start and its address, the rest zero.
  private func record(deleted: Bool = false, start value: UInt32, address: UInt32 = 0) -> Data {
    var bytes = Data(deleted ? [0x5A, 0x23] : [0xA5, 0xC4]) + Data(count: 2) + start(value)
    bytes += Data(count: 12)
    bytes += start(address)
    return bytes + Data(count: 8)
  }

  private func page(_ records: [Data]) -> Data {
    let bytes = records.reduce(Data(), +)
    return bytes + Data(count: max(0, PetrelManifest.pageSize - bytes.count))
  }

  @Test func theProbesPageHoldsElevenDivesAndEnds() throws {
    let page = PetrelManifest.Page(try probePage())
    #expect(page.records.count == 11)
    #expect(!page.continues)
    #expect(page.records.allSatisfy { !$0.isDeleted })
    let newest = try #require(page.records.first)
    #expect(newest.start == start(0x6ADF_6BBB))
    #expect(newest.address == 0x0002_C260)
    #expect(page.records.last?.start == start(0x6AA0_2732))
  }

  @Test func theNewDivesAreThoseBeforeTheFingerprint() throws {
    let records = PetrelManifest.Page(try probePage()).records
    let all = PetrelManifest.select(records, fingerprint: nil)
    #expect(all.listing == DiveComputerListing(dives: 11, newDives: 11, newEntries: 11))
    #expect(all.new == records)

    let three = PetrelManifest.select(records, fingerprint: start(0x6AB1_0B71))
    #expect(three.listing == DiveComputerListing(dives: 11, newDives: 3, newEntries: 3))
    #expect(three.new.map(\.address) == [0x0002_C260, 0x0002_8660, 0x0002_52C0])

    let none = PetrelManifest.select(records, fingerprint: start(0x6ADF_6BBB))
    #expect(none.listing.newDives == 0)
    #expect(none.new.isEmpty)

    #expect(PetrelManifest.select(records, fingerprint: start(0x1234_5678)).listing.newDives == 11)
  }

  @Test func deletedDivesAreSkippedWhereverTheySit() {
    let records = PetrelManifest.Page(
      page([
        record(start: 50, address: 5), record(deleted: true, start: 40),
        record(start: 30, address: 3), record(deleted: true, start: 20),
        record(start: 10, address: 1),
      ])
    ).records
    #expect(records.count == 5)
    let selection = PetrelManifest.select(records, fingerprint: start(10))
    #expect(selection.listing == DiveComputerListing(dives: 3, newDives: 2, newEntries: 2))
    #expect(selection.new.map(\.address) == [5, 3])
    // A deleted record's start is no stopping point.
    #expect(PetrelManifest.select(records, fingerprint: start(40)).listing.newDives == 3)
  }

  @Test func aFullPageIsFollowedByTheNext() {
    var full: [Data] = []
    for index in 0..<PetrelManifest.recordsPerPage {
      let value = UInt32(index)
      full.append(record(deleted: index % 7 == 3, start: 1000 - value, address: value))
    }
    let first = PetrelManifest.Page(page(full))
    #expect(first.continues)
    let second = PetrelManifest.Page(page([record(start: 900, address: 99)]))
    #expect(!second.continues)
    let records = first.records + second.records
    #expect(records.count == 49)
    let live = records.count { !$0.isDeleted }
    #expect(live == 49 - 7)
    let all = PetrelManifest.select(records, fingerprint: nil)
    #expect(all.listing.dives == live)
    #expect(all.new.last?.address == 99)
    #expect(PetrelManifest.select(records, fingerprint: start(900)).listing.newDives == live - 1)
  }

  @Test func theIdentifierAnswersDecodeAsLibdivecomputersWalk() {
    #expect(PetrelIdentifier.serial(Data("0A1B2C3D".utf8)) == "0A1B2C3D")
    #expect(PetrelIdentifier.serial(Data("0a1b2c3d".utf8)) == "0A1B2C3D")
    #expect(PetrelIdentifier.serial(Data("0A1B2C3".utf8)) == nil)
    #expect(PetrelIdentifier.serial(Data("+A1B2C3D".utf8)) == nil)
    #expect(PetrelIdentifier.firmware(Data("V39 Classic".utf8)) == 39)
    #expect(PetrelIdentifier.firmware(Data("Vx".utf8)) == 0)
    #expect(PetrelIdentifier.logBase(Data([0x01, 0x80, 0, 0, 0, 0, 0x02, 0, 0x80])) == 0x8000_0000)
    #expect(PetrelIdentifier.logBase(Data([0x01, 0xDD, 0, 0, 0])) == 0xC000_0000)
    #expect(PetrelIdentifier.logBase(Data([0x01, 0x90, 0, 0, 0])) == 0xC000_0000)
    #expect(PetrelIdentifier.logBase(Data([0x01, 0x70, 0, 0, 0])) == nil)
    #expect(PetrelIdentifier.logBase(Data([0x01, 0x80])) == nil)
  }
}
