import Clibdivecomputer
import CoreBluetooth
import Foundation
import LibDCBridge
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
