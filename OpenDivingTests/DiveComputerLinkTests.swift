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

  /// A cancel or a lost link stops the walk at once; any other failure no other app's handshake
  /// broke asks whether the watch is busy first, and while it is the transfer is tried again
  /// whatever it is.
  @Test func aFailedTransferAsksWhetherTheWatchIsBusyUnlessTheLinkIsGone() {
    let fetches: [LibDCWalk.NauticFetch] = [
      .listing, .summary, .download(counted: true), .download(counted: false),
    ]
    for fetch in fetches {
      let success = LibDCWalk.nauticNext(
        fetch, status: DC_STATUS_SUCCESS, otherApp: false, busy: nil, freeFailures: 0, reconnects: 0
      )
      #expect(success == .take)
      for status in [DC_STATUS_CANCELLED, DC_STATUS_IO, DC_STATUS_NODEVICE] {
        let next = LibDCWalk.nauticNext(
          fetch, status: status, otherApp: false, busy: nil, freeFailures: 0, reconnects: 0)
        #expect(next == .stop(status))
      }
      for status in [DC_STATUS_TIMEOUT, DC_STATUS_PROTOCOL, DC_STATUS_DATAFORMAT] {
        let unasked = LibDCWalk.nauticNext(
          fetch, status: status, otherApp: false, busy: nil, freeFailures: 0, reconnects: 0)
        #expect(unasked == .readBusy)
        let busy = LibDCWalk.nauticNext(
          fetch, status: status, otherApp: false, busy: true, freeFailures: 5, reconnects: 0)
        #expect(busy == .retry)
      }
    }
  }

  /// A summary, the descriptors or a download another app's handshake broke is waited out and
  /// tried again on the same connection, however often and whatever the failure, before the watch
  /// is asked and without counting a retry or a reopen; a cancel or a lost link still stops the
  /// walk, and the listing fails as any other failure does.
  @Test func aTransferAnotherAppBrokeIsWaitedOutOnTheSameConnection() {
    let fetches: [LibDCWalk.NauticFetch] = [
      .summary, .download(counted: true), .download(counted: false),
    ]
    for fetch in fetches {
      for status in [DC_STATUS_TIMEOUT, DC_STATUS_PROTOCOL, DC_STATUS_DATAFORMAT] {
        let first = LibDCWalk.nauticNext(
          fetch, status: status, otherApp: true, busy: nil, freeFailures: 0, reconnects: 0)
        #expect(first == .awaitOtherApp)
        let spent = LibDCWalk.nauticNext(
          fetch, status: status, otherApp: true, busy: nil, freeFailures: 3, reconnects: 3)
        #expect(spent == .awaitOtherApp)
      }
      let taken = LibDCWalk.nauticNext(
        fetch, status: DC_STATUS_SUCCESS, otherApp: true, busy: nil, freeFailures: 0,
        reconnects: 0)
      #expect(taken == .take)
      for status in [DC_STATUS_CANCELLED, DC_STATUS_IO, DC_STATUS_NODEVICE] {
        let next = LibDCWalk.nauticNext(
          fetch, status: status, otherApp: true, busy: nil, freeFailures: 0, reconnects: 0)
        #expect(next == .stop(status))
      }
    }
    let listing = LibDCWalk.nauticNext(
      .listing, status: DC_STATUS_TIMEOUT, otherApp: true, busy: nil, freeFailures: 0,
      reconnects: 0)
    #expect(listing == .readBusy)
  }

  /// A timeout while the watch says free reopens the device at once, whatever the transfer and
  /// however often it failed, until the walk has made three reopens; no other failure does.
  @Test func aTimeoutWhileFreeReconnectsUntilTheReopensAreSpent() {
    let fetches: [LibDCWalk.NauticFetch] = [
      .listing, .summary, .download(counted: true), .download(counted: false),
    ]
    for fetch in fetches {
      for made in 0..<3 {
        let next = LibDCWalk.nauticNext(
          fetch, status: DC_STATUS_TIMEOUT, otherApp: false, busy: false, freeFailures: 1 + made,
          reconnects: made)
        #expect(next == .reconnect)
      }
      let refused = LibDCWalk.nauticNext(
        fetch, status: DC_STATUS_PROTOCOL, otherApp: false, busy: false, freeFailures: 1,
        reconnects: 0)
      #expect(refused != .reconnect)
      let spent = LibDCWalk.nauticNext(
        fetch, status: DC_STATUS_TIMEOUT, otherApp: false, busy: false, freeFailures: 4,
        reconnects: 3)
      #expect(spent != .reconnect)
    }
    #expect(LibDCWalk.reconnects(after: DC_STATUS_TIMEOUT, made: 2))
    #expect(!LibDCWalk.reconnects(after: DC_STATUS_TIMEOUT, made: 3))
    #expect(!LibDCWalk.reconnects(after: DC_STATUS_IO, made: 0))
  }

  /// Once the reopens are spent, a failed listing stops the walk and a summary that timed out
  /// reads as unread.
  @Test func whileFreeAListingStopsAndASummaryIsUnread() {
    let listing = LibDCWalk.nauticNext(
      .listing, status: DC_STATUS_PROTOCOL, otherApp: false, busy: false, freeFailures: 1,
      reconnects: 0)
    #expect(listing == .stop(DC_STATUS_PROTOCOL))
    let summary = LibDCWalk.nauticNext(
      .summary, status: DC_STATUS_TIMEOUT, otherApp: false, busy: false, freeFailures: 1,
      reconnects: 3)
    #expect(summary == .passOver)
  }

  /// Once the reopens are spent, a counted download is tried three times while free, an
  /// uncounted one once; then a timeout stops the walk and any other failure leaves the entry out.
  @Test func aDownloadIsRetriedThenStopsOnAStallOrPassesOver() {
    let counted = LibDCWalk.NauticFetch.download(counted: true)
    let uncounted = LibDCWalk.NauticFetch.download(counted: false)
    for status in [DC_STATUS_TIMEOUT, DC_STATUS_PROTOCOL] {
      let first = LibDCWalk.nauticNext(
        counted, status: status, otherApp: false, busy: false, freeFailures: 1, reconnects: 3)
      #expect(first == .retry)
      let second = LibDCWalk.nauticNext(
        counted, status: status, otherApp: false, busy: false, freeFailures: 2, reconnects: 3)
      #expect(second == .retry)
    }
    let stalled = LibDCWalk.nauticNext(
      counted, status: DC_STATUS_TIMEOUT, otherApp: false, busy: false, freeFailures: 3,
      reconnects: 3)
    #expect(stalled == .stop(DC_STATUS_TIMEOUT))
    let refused = LibDCWalk.nauticNext(
      counted, status: DC_STATUS_PROTOCOL, otherApp: false, busy: false, freeFailures: 3,
      reconnects: 0)
    #expect(refused == .passOver)
    let malformed = LibDCWalk.nauticNext(
      counted, status: DC_STATUS_DATAFORMAT, otherApp: false, busy: false, freeFailures: 3,
      reconnects: 0)
    #expect(malformed == .passOver)
    let uncountedStall = LibDCWalk.nauticNext(
      uncounted, status: DC_STATUS_TIMEOUT, otherApp: false, busy: false, freeFailures: 1,
      reconnects: 3)
    #expect(uncountedStall == .stop(DC_STATUS_TIMEOUT))
    let uncountedRefused = LibDCWalk.nauticNext(
      uncounted, status: DC_STATUS_PROTOCOL, otherApp: false, busy: false, freeFailures: 1,
      reconnects: 0)
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
