import Clibdivecomputer
import CoreBluetooth
import Foundation
import LibDCBridge
import LibDCSwift
import OpenDivingKit
import Testing

@testable import OpenDiving

/// The libdc-swift conformance without a radio: Bluetooth's state as the central reports it,
/// names resolved over libdivecomputer's own descriptor table, the outcome rules, and what a
/// session leaves in the defaults.
@MainActor
struct DiveComputerLinkTests {
  private func link(_ defaults: UserDefaults = .standard) -> LibDCDiveComputerLink {
    LibDCDiveComputerLink(manager: nil, defaults: defaults)
  }

  @Test func availabilityFollowsTheCentralAndItsAuthorization() async {
    let link = link()
    let stream = link.availability()
    link.receive(.poweredOn, authorization: .allowedAlways)
    link.receive(.poweredOn, authorization: .allowedAlways)
    link.receive(.poweredOff, authorization: .allowedAlways)
    link.receive(.unauthorized, authorization: .denied)
    var seen: [DiveComputerAvailability] = []
    for await state in stream {
      seen.append(state)
      if seen.count == 4 { break }
    }
    #expect(seen == [.unknown, .on, .off, .refused])
  }

  @Test func aRefusedAuthorizationIsRefusedWhateverTheState() {
    #expect(LibDCDiveComputerLink.availability(.poweredOn, .denied) == .refused)
    #expect(LibDCDiveComputerLink.availability(.poweredOn, .restricted) == .refused)
    #expect(LibDCDiveComputerLink.availability(.unsupported, .allowedAlways) == .off)
    #expect(LibDCDiveComputerLink.availability(.resetting, .allowedAlways) == .unknown)
  }

  @Test func aNameEqualToAProductIsThatProduct() throws {
    let perdix3 = try #require(LibDCNames.resolve("Perdix 3"))
    #expect(perdix3.family == .shearwaterPetrel)
    #expect(perdix3.vendor == "Shearwater")
    #expect(perdix3.model == 14)
    #expect(LibDCNames.resolve("perdix")?.model == 5)
  }

  @Test func aNauticIsResolvedByThePackageAndCarriesItsSerial() throws {
    let found = LibDCNames.found(name: "Suunto Ocean 253810000400", id: UUID())
    #expect(found.family == .suuntoNautic)
    #expect(found.product == "Ocean")
    #expect(found.modelNumber == 1)
    #expect(found.advertisedSerial == "253810000400")
    #expect(found.title == "Suunto Ocean")
  }

  @Test func aNameNothingKnowsIsLeftUnresolved() {
    let found = LibDCNames.found(name: "Kettle", id: UUID())
    #expect(found.family == nil)
    #expect(found.title == "Kettle")
  }

  @Test func theKitsFamilyNamesMapToLibdivecomputersAndBack() throws {
    #expect(LibDCNames.family(DC_FAMILY_SHEARWATER_PETREL) == .shearwaterPetrel)
    #expect(LibDCNames.family(DC_FAMILY_SUUNTO_NAUTIC) == .suuntoNautic)
    #expect(LibDCNames.dcFamily(.shearwaterPetrel) == DC_FAMILY_SHEARWATER_PETREL)
    #expect(LibDCNames.dcFamily(.suuntoNautic) == DC_FAMILY_SUUNTO_NAUTIC)
  }

  @Test func firmwareIsSpelledAsTheFamilysExportsSpellIt() {
    #expect(LibDCNames.firmware(93, family: .shearwaterPetrel) == "93")
    #expect(LibDCNames.firmware(0x02_04_06, family: .suuntoNautic) == "2.4.6")
    #expect(LibDCNames.firmware(0, family: .shearwaterPetrel) == nil)
  }

  @Test func aWalkStoppedAtTheFingerprintIsComplete() {
    let end = LibDCWalk.end(
      status: DC_STATUS_SUCCESS, cancelled: false, family: .shearwaterPetrel, delivered: 0,
      emptyReads: 0, refused: 0, fingerprintSet: true)
    #expect(end.kind == .complete)
  }

  @Test func aProtocolEndWithNothingNewIsCompleteButForTheNautic() {
    func end(_ family: DiveComputerFamily) -> DiveComputerDownloadEnd.Kind {
      LibDCWalk.end(
        status: DC_STATUS_PROTOCOL, cancelled: false, family: family, delivered: 0,
        emptyReads: 0, refused: 0, fingerprintSet: true
      ).kind
    }
    #expect(end(.shearwaterPetrel) == .complete)
    #expect(end(.suuntoNautic) == .failed(status: "DC_STATUS_PROTOCOL"))
    let unset = LibDCWalk.end(
      status: DC_STATUS_PROTOCOL, cancelled: false, family: .shearwaterPetrel, delivered: 0,
      emptyReads: 0, refused: 0, fingerprintSet: false)
    #expect(unset.kind == .failed(status: "DC_STATUS_PROTOCOL"))
  }

  @Test func anOpenThatGetsNoAnswerIsUnreachable() {
    #expect(LibDCDeviceSession.openFailure(DC_STATUS_IO) == .unreachable)
    #expect(LibDCDeviceSession.openFailure(DC_STATUS_TIMEOUT) == .unreachable)
    #expect(
      LibDCDeviceSession.openFailure(DC_STATUS_UNSUPPORTED)
        == .failed(status: "DC_STATUS_UNSUPPORTED"))
  }

  @Test func aWalkOfOnlyEmptyRecordsFails() {
    let end = LibDCWalk.end(
      status: DC_STATUS_SUCCESS, cancelled: false, family: .suuntoNautic, delivered: 0,
      emptyReads: 2, refused: 0, fingerprintSet: false)
    #expect(end.kind == .failed(status: "DC_STATUS_DATAFORMAT"))
    #expect(end.emptyReads == 2)
    let some = LibDCWalk.end(
      status: DC_STATUS_SUCCESS, cancelled: false, family: .suuntoNautic, delivered: 3,
      emptyReads: 1, refused: 1, fingerprintSet: false)
    #expect(some.kind == .complete)
    #expect(some.emptyReads == 1)
    #expect(some.refused == 1)
  }

  @Test func aCancelIsACancelWhateverTheStatus() {
    for status in [DC_STATUS_SUCCESS, DC_STATUS_CANCELLED, DC_STATUS_IO] {
      let end = LibDCWalk.end(
        status: status, cancelled: status != DC_STATUS_CANCELLED, family: .shearwaterPetrel,
        delivered: 2, emptyReads: 0, refused: 0, fingerprintSet: false)
      #expect(end.kind == .cancelled)
    }
  }

  /// The by-id download: bytes are a dive, a short one too; no bytes are passed over; any other
  /// status stops the walk.
  @Test func aDownloadByIdIsDeliveredPassedOverOrStops() {
    let bytes = Data([1, 2, 3])
    let empty = Data()
    #expect(LibDCWalk.nauticDownload(status: DC_STATUS_SUCCESS, bytes: bytes) == .deliver(bytes))
    #expect(
      LibDCWalk.nauticDownload(status: DC_STATUS_DATAFORMAT, bytes: bytes) == .deliver(bytes))
    #expect(LibDCWalk.nauticDownload(status: DC_STATUS_DATAFORMAT, bytes: empty) == .passOver)
    #expect(LibDCWalk.nauticDownload(status: DC_STATUS_SUCCESS, bytes: empty) == .passOver)
    for status in [DC_STATUS_TIMEOUT, DC_STATUS_IO, DC_STATUS_PROTOCOL, DC_STATUS_CANCELLED] {
      #expect(LibDCWalk.nauticDownload(status: status, bytes: empty) == .stop(status))
    }
  }

  /// A summary that cannot be read leaves the entry a dive; a cancel or a gone link stops the walk.
  @Test func aSummaryIsBytesEmptyUnreadOrStops() {
    let bytes = Data([1])
    let empty = Data()
    #expect(LibDCWalk.nauticSummary(status: DC_STATUS_SUCCESS, bytes: bytes) == .bytes)
    #expect(LibDCWalk.nauticSummary(status: DC_STATUS_SUCCESS, bytes: empty) == .empty)
    #expect(LibDCWalk.nauticSummary(status: DC_STATUS_PROTOCOL, bytes: empty) == .unread)
    #expect(LibDCWalk.nauticSummary(status: DC_STATUS_TIMEOUT, bytes: empty) == .unread)
    for status in [DC_STATUS_CANCELLED, DC_STATUS_IO, DC_STATUS_NODEVICE] {
      #expect(LibDCWalk.nauticSummary(status: status, bytes: empty) == .stop(status))
    }
  }

  /// A walk whose every download of a counted entry came back empty delivered nothing and fails;
  /// one that delivered a dive, met any download with bytes, or whose empty downloads were all of
  /// uncounted entries, is complete.
  @Test func aWalkOfOnlyEmptyDownloadsFails() {
    func end(delivered: Int, downloads: Int, emptyDownloads: Int) -> DiveComputerDownloadEnd {
      LibDCWalk.end(
        status: DC_STATUS_SUCCESS, cancelled: false, family: .suuntoNautic, delivered: delivered,
        emptyReads: 0, refused: 0, fingerprintSet: false, downloads: downloads,
        emptyDownloads: emptyDownloads)
    }
    let failed = DiveComputerDownloadEnd.Kind.failed(status: "DC_STATUS_DATAFORMAT")
    #expect(end(delivered: 0, downloads: 2, emptyDownloads: 2).kind == failed)
    #expect(end(delivered: 0, downloads: 2, emptyDownloads: 2).emptyReads == 0)
    #expect(end(delivered: 1, downloads: 3, emptyDownloads: 2).kind == .complete)
    #expect(end(delivered: 0, downloads: 2, emptyDownloads: 1).kind == .complete)
    #expect(end(delivered: 0, downloads: 0, emptyDownloads: 0).kind == .complete)
    let cancelled = LibDCWalk.end(
      status: DC_STATUS_SUCCESS, cancelled: true, family: .suuntoNautic, delivered: 0,
      emptyReads: 0, refused: 0, fingerprintSet: false, downloads: 1, emptyDownloads: 1)
    #expect(cancelled.kind == .cancelled)
  }

  @Test func theListedIdsAreFourLittleEndianBytesEach() {
    let list = Data([0x2D, 0xD7, 0xDF, 0x6A, 0x01, 0x00, 0x00, 0x00, 0xFF])
    #expect(LibDCWalk.nauticIDs(list) == [1_793_054_509, 1])
    #expect(LibDCWalk.nauticIDs(Data()).isEmpty)
  }

  /// The busy state as libdc-swift's test watch encodes it: a uint8 after its type.
  @Test func aWatchIsBusyWhileItsValueIsNonZero() {
    let busy = SuuntoNauticExplorer.WhiteboardValue(encoded: Data([0x03, 0x00, 0x01]))
    let free = SuuntoNauticExplorer.WhiteboardValue(encoded: Data([0x03, 0x00, 0x00]))
    #expect(LibDCWalk.isBusy(busy))
    #expect(!LibDCWalk.isBusy(free))
    #expect(!LibDCWalk.isBusy(nil))
  }

  @Test func aSessionLeavesNothingThePackageWrote() throws {
    let name = "DiveComputerLinkTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    for key in LibDCDeviceSession.packageDefaultsKeys {
      defaults.set(Data([1]), forKey: key)
    }
    let session = LibDCDeviceSession(defaults: defaults)
    let device = try #require(calloc(1, MemoryLayout<device_data_t>.size))
      .assumingMemoryBound(to: device_data_t.self)
    session.queue.sync { session.close(device) }
    for key in LibDCDeviceSession.packageDefaultsKeys {
      #expect(defaults.object(forKey: key) == nil)
    }
  }
}
