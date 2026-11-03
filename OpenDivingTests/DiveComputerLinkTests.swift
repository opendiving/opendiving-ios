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
      status: DC_STATUS_SUCCESS, cancelled: false, family: .shearwaterPetrel, delivered: 0,
      emptyReads: 2, refused: 0, fingerprintSet: false)
    #expect(end.kind == .failed(status: "DC_STATUS_DATAFORMAT"))
    #expect(end.emptyReads == 2)
    let some = LibDCWalk.end(
      status: DC_STATUS_SUCCESS, cancelled: false, family: .shearwaterPetrel, delivered: 3,
      emptyReads: 1, refused: 1, fingerprintSet: false)
    #expect(some.kind == .complete)
    #expect(some.emptyReads == 1)
    #expect(some.refused == 1)
  }

  @Test func theEndCarriesTheEntriesLeftOut() {
    let end = LibDCWalk.end(
      status: DC_STATUS_SUCCESS, cancelled: false, family: .suuntoNautic, delivered: 0,
      emptyReads: 0, refused: 0, fingerprintSet: false, waiting: 2, notDownloaded: 1)
    #expect(end.kind == .complete)
    #expect(end.waiting == 2)
    #expect(end.notDownloaded == 1)
  }

  @Test func aCancelIsACancelWhateverTheStatus() {
    for status in [DC_STATUS_SUCCESS, DC_STATUS_CANCELLED, DC_STATUS_IO] {
      let end = LibDCWalk.end(
        status: status, cancelled: status != DC_STATUS_CANCELLED, family: .shearwaterPetrel,
        delivered: 2, emptyReads: 0, refused: 0, fingerprintSet: false)
      #expect(end.kind == .cancelled)
    }
  }

  /// A cancel or a lost link stops the walk at once; any other failure asks whether the watch is
  /// busy first, and while it is the transfer is tried again whatever it is.
  @Test func aFailedTransferAsksWhetherTheWatchIsBusyUnlessTheLinkIsGone() {
    let fetches: [LibDCWalk.NauticFetch] = [
      .listing, .summary, .download(counted: true), .download(counted: false),
    ]
    for fetch in fetches {
      let success = LibDCWalk.nauticNext(
        fetch, status: DC_STATUS_SUCCESS, busy: nil, freeFailures: 0)
      #expect(success == .take)
      for status in [DC_STATUS_CANCELLED, DC_STATUS_IO, DC_STATUS_NODEVICE] {
        let next = LibDCWalk.nauticNext(fetch, status: status, busy: nil, freeFailures: 0)
        #expect(next == .stop(status))
      }
      for status in [DC_STATUS_TIMEOUT, DC_STATUS_PROTOCOL, DC_STATUS_DATAFORMAT] {
        let unasked = LibDCWalk.nauticNext(fetch, status: status, busy: nil, freeFailures: 0)
        #expect(unasked == .readBusy)
        let busy = LibDCWalk.nauticNext(fetch, status: status, busy: true, freeFailures: 5)
        #expect(busy == .retry)
      }
    }
  }

  /// While the watch says free, a failed listing stops the walk and a failed summary reads as
  /// unread.
  @Test func whileFreeAListingStopsAndASummaryIsUnread() {
    let listing = LibDCWalk.nauticNext(
      .listing, status: DC_STATUS_PROTOCOL, busy: false, freeFailures: 1)
    #expect(listing == .stop(DC_STATUS_PROTOCOL))
    let summary = LibDCWalk.nauticNext(
      .summary, status: DC_STATUS_TIMEOUT, busy: false, freeFailures: 1)
    #expect(summary == .passOver)
  }

  /// A counted download is tried three times while free, an uncounted one once; then a stall
  /// stops the walk and any other failure leaves the entry out.
  @Test func aDownloadIsRetriedThenStopsOnAStallOrPassesOver() {
    let counted = LibDCWalk.NauticFetch.download(counted: true)
    let uncounted = LibDCWalk.NauticFetch.download(counted: false)
    for status in [DC_STATUS_TIMEOUT, DC_STATUS_PROTOCOL] {
      let first = LibDCWalk.nauticNext(counted, status: status, busy: false, freeFailures: 1)
      #expect(first == .retry)
      let second = LibDCWalk.nauticNext(counted, status: status, busy: false, freeFailures: 2)
      #expect(second == .retry)
    }
    let stalled = LibDCWalk.nauticNext(
      counted, status: DC_STATUS_TIMEOUT, busy: false, freeFailures: 3)
    #expect(stalled == .stop(DC_STATUS_TIMEOUT))
    let refused = LibDCWalk.nauticNext(
      counted, status: DC_STATUS_PROTOCOL, busy: false, freeFailures: 3)
    #expect(refused == .passOver)
    let malformed = LibDCWalk.nauticNext(
      counted, status: DC_STATUS_DATAFORMAT, busy: false, freeFailures: 3)
    #expect(malformed == .passOver)
    let uncountedStall = LibDCWalk.nauticNext(
      uncounted, status: DC_STATUS_TIMEOUT, busy: false, freeFailures: 1)
    #expect(uncountedStall == .stop(DC_STATUS_TIMEOUT))
    let uncountedRefused = LibDCWalk.nauticNext(
      uncounted, status: DC_STATUS_PROTOCOL, busy: false, freeFailures: 1)
    #expect(uncountedRefused == .passOver)
  }

  /// A Nautic reading that holds no dive is an empty or aborted session, skipped as a run is;
  /// every other family counts it as an empty read.
  @Test func onlyTheNauticSkipsAReadingThatHoldsNoDive() {
    #expect(LibDCWalk.skipsEmpty(.suuntoNautic))
    #expect(!LibDCWalk.skipsEmpty(.shearwaterPetrel))
  }

  /// Nautic bytes without the SBEM container's header are a session that holds no dive, skipped
  /// whatever the parser says; bytes with it go to the parser, which may refuse a newer version
  /// and keep it; other families are always parsed.
  @Test func onlyNauticBytesWithoutTheSBEMHeaderAreSkippedUnparsed() {
    let unframed = Data([0x00, 0x01, 0x02, 0x03, 0x04])
    let newerVersion = Data("SBEM0104".utf8)
    let current = Data("SBEM0103".utf8)
    let empty = Data()
    #expect(LibDCWalk.skipsUnframed(unframed, family: .suuntoNautic))
    #expect(LibDCWalk.skipsUnframed(empty, family: .suuntoNautic))
    #expect(!LibDCWalk.skipsUnframed(newerVersion, family: .suuntoNautic))
    #expect(!LibDCWalk.skipsUnframed(current, family: .suuntoNautic))
    #expect(!LibDCWalk.skipsUnframed(unframed, family: .shearwaterPetrel))
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
