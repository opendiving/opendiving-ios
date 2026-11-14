import Foundation
import Testing

@testable import OpenDivingKit

/// Where the remembered computers live, and what survives what.
@MainActor
struct DiveComputerStoreTests {
  private typealias F = DiveComputerFixtures

  private let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("DiveComputerStoreTests-\(UUID().uuidString)", isDirectory: true)

  private var stateStore: ServerStateStore {
    ServerStateStore(
      root: root, secrets: InMemorySecretStore(),
      activeOrigin: InMemoryActiveOriginStore(ImportServer.origin))
  }

  private var store: DiveComputerStore {
    DiveComputerStore(
      store: stateStore, origin: ImportServer.origin, account: ImportServer.accountA)
  }

  private var folder: URL {
    stateStore.directory(for: ImportServer.origin, account: ImportServer.accountA)
      .appendingPathComponent("DiveComputers", isDirectory: true)
  }

  private let otherOrigin = ServerOrigin("https://other.example")!

  private var otherServer: DiveComputerStore {
    DiveComputerStore(store: stateStore, origin: otherOrigin, account: ImportServer.accountB)
  }

  @Test func aPairingWrittenBeforeTheHardwareWasKeptStillDecodes() throws {
    let encoded = try JSONEncoder().encode(PairedComputer(DiveComputerRecord(identity: F.perdix)))
    var fields = try #require(
      try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    fields["hardware"] = nil
    let record = try JSONDecoder().decode(
      PairedComputer.self, from: JSONSerialization.data(withJSONObject: fields))
    #expect(record.hardware == nil)
    #expect(record.serial == "D9772626")
  }

  @Test func aPairingWrittenBeforeTheSwitchDownloadsAutomatically() throws {
    var computer = DiveComputerRecord(identity: F.perdix)
    computer.downloadsAutomatically = false
    let encoded = try JSONEncoder().encode(PairedComputer(computer))
    var fields = try #require(
      try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    #expect(fields["downloadsAutomatically"] as? Bool == false)
    fields["downloadsAutomatically"] = nil
    let paired = try JSONDecoder().decode(
      PairedComputer.self, from: JSONSerialization.data(withJSONObject: fields))
    #expect(DiveComputerRecord(paired, progress: nil).downloadsAutomatically)
  }

  @Test func thePairingsAreReadWithoutAnAccountAndTheHintMovesAlone() throws {
    var record = DiveComputerRecord(identity: F.ocean, peripheral: F.oceanFound.id)
    record.downloadsAutomatically = false
    try store.save(record)
    let moved = UUID()
    try store.follow(record, to: moved)

    let read = try #require(DiveComputerStore.pairings(applicationSupport: root).first)
    #expect(read.peripheral == moved)
    #expect(!read.downloadsAutomatically)
    #expect(read.fingerprint == nil)
    #expect(store.record(family: .suuntoNautic, serial: F.ocean.serial)?.peripheral == moved)
    // A computer not paired is not paired by a move.
    try store.follow(DiveComputerRecord(identity: F.perdix), to: moved)
    #expect(DiveComputerStore.pairings(applicationSupport: root).count == 1)
  }

  @Test func aComputersPageShowsWhatItReportedAndLeavesOutTheRest() {
    var record = DiveComputerRecord(identity: F.perdix, lastDownloaded: F.moment)
    record.hardware = "0B0B"
    let page = DiveComputerPageContent(record, in: F.helsinki)
    #expect(page.title == "Shearwater Perdix 3")
    #expect(
      page.facts.map(\.label) == [
        "Serial number", "Hardware version", "Firmware version", "Last downloaded",
      ])
    #expect(page.facts.map(\.value) == ["D9772626", "0B0B", "93", "25 October"])

    record.hardware = nil
    record.firmware = nil
    record.lastDownloaded = nil
    #expect(DiveComputerPageContent(record).facts.map(\.label) == ["Serial number"])
  }

  @Test func aRecordIsOneFileForThePhoneAndOneForTheAccountFoundInEitherCase() throws {
    try store.save(DiveComputerRecord(identity: F.perdix, fingerprint: F.fingerprint(3)))
    for directory in [folder, stateStore.diveComputersDirectory] {
      #expect(
        try FileManager.default.contentsOfDirectory(atPath: directory.path) == [
          "shearwater-petrel_D9772626.json"
        ])
    }
    #expect(
      store.record(family: .shearwaterPetrel, serial: "d9772626")?.fingerprint == F.fingerprint(3))
    #expect(store.record(family: .suuntoNautic, serial: "D9772626") == nil)
  }

  @Test(arguments: [false, true])
  func aFileThisBuildCannotReadIsKeptAndNeverOverwritten(inTheAccount: Bool) throws {
    let directory = inTheAccount ? folder : stateStore.diveComputersDirectory
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let unreadable = directory.appendingPathComponent("shearwater-petrel_D9772626.json")
    try Data(#"{"family": 7}"#.utf8).write(to: unreadable)
    try store.save(DiveComputerRecord(identity: F.ocean))

    #expect(store.records().map(\.serial) == ["253810000400"])
    #expect(store.unreadableCount == (inTheAccount ? 0 : 1))
    #expect(throws: DiveComputerStoreError.unreadableRecord) {
      try store.save(DiveComputerRecord(identity: F.perdix))
    }
    #expect(try Data(contentsOf: unreadable) == Data(#"{"family": 7}"#.utf8))
  }

  @Test func forgettingTheServerRemovesItsProgressAndLeavesThePairing() throws {
    try store.save(DiveComputerRecord(identity: F.perdix, fingerprint: F.fingerprint(3)))
    try stateStore.endSession(for: ImportServer.origin)
    #expect(store.records().first?.fingerprint == F.fingerprint(3))
    try stateStore.forget(ImportServer.origin)
    #expect(store.records().map(\.serial) == ["D9772626"])
    #expect(store.records().first?.fingerprint == nil)
  }

  @Test func aComputerPairedOnOneServerIsListedOnAnotherWithNoneOfItsProgress() throws {
    var record = DiveComputerRecord(
      identity: F.ocean, fingerprint: F.fingerprint(3), lastDownloaded: F.moment)
    record.nauticSports = [NauticEntrySport(id: 1, sport: nil)]
    try store.save(record)

    let there = try #require(otherServer.record(family: .suuntoNautic, serial: record.serial))
    #expect(there.title == record.title)
    #expect(there.nauticSports == record.nauticSports)
    #expect(there.fingerprint == nil)
    #expect(there.lastDownloaded == nil)

    var moved = there
    moved.fingerprint = F.fingerprint(9)
    try otherServer.save(moved)
    #expect(store.records().first?.fingerprint == F.fingerprint(3))
    #expect(otherServer.records().first?.fingerprint == F.fingerprint(9))
  }

  @Test func forgettingAComputerForgetsItOnEveryServer() throws {
    let record = DiveComputerRecord(identity: F.perdix, fingerprint: F.fingerprint(3))
    try store.save(record)
    try otherServer.save(record)
    otherServer.forget(record)
    #expect(store.records().isEmpty)

    try store.save(DiveComputerRecord(identity: F.perdix))
    #expect(store.records().first?.fingerprint == nil)
    #expect(otherServer.records().first?.fingerprint == nil)
  }

  @Test func aMarkRemovedTakesTheProgressAndLeavesThePairing() throws {
    try store.save(
      DiveComputerRecord(
        identity: F.perdix, fingerprint: F.fingerprint(3), receivedBeforeAccountKnown: true))
    store.removeMarked()
    #expect(store.records().map(\.serial) == ["D9772626"])
    #expect(store.records().first?.fingerprint == nil)
  }

  @Test func wholeRecordsInAccountFoldersBecomePairingsAndKeepTheirProgress() throws {
    let older = DiveComputerRecord(
      identity: F.perdix, peripheral: UUID(), fingerprint: F.fingerprint(1),
      lastDownloaded: F.moment.addingTimeInterval(-60))
    let newer = DiveComputerRecord(
      identity: F.perdix, peripheral: UUID(), fingerprint: F.fingerprint(2),
      lastDownloaded: F.moment)
    try F.writeWholeRecord(older, in: folder)
    try F.writeWholeRecord(
      newer,
      in: stateStore.directory(for: otherOrigin, account: ImportServer.accountB)
        .appendingPathComponent("DiveComputers", isDirectory: true))

    DiveComputerStore.adoptAccountRecords(store: stateStore)

    #expect(store.records().map(\.peripheral) == [newer.peripheral])
    #expect(store.records().first?.fingerprint == F.fingerprint(1))
    #expect(otherServer.records().first?.fingerprint == F.fingerprint(2))
  }

  @Test func aForgottenComputerIsNotAdoptedAgain() throws {
    let record = DiveComputerRecord(identity: F.perdix, fingerprint: F.fingerprint(1))
    try F.writeWholeRecord(record, in: folder)
    DiveComputerStore.adoptAccountRecords(store: stateStore)
    store.forget(record)
    DiveComputerStore.adoptAccountRecords(store: stateStore)
    #expect(store.records().isEmpty)
  }

  @Test func theForgetConfirmationNamesTheComputer() {
    #expect(
      DiveComputerText.forgetTitle(DiveComputerRecord(identity: F.perdix)) == "Forget Perdix 3?")
  }

  // MARK: - The family's rules

  @Test func eachFamilySpellsItsModelAndSerialAsItsExportsDo() {
    #expect(
      DiveComputerFamily.shearwaterPetrel.deviceModel(vendor: "Shearwater", product: "Perdix 3")
        == "Perdix 3")
    #expect(
      DiveComputerFamily.suuntoNautic.deviceModel(vendor: "Suunto", product: "Ocean")
        == "Suunto Ocean")
    #expect(
      DiveComputerFamily.suuntoNautic.deviceModel(vendor: "Suunto", product: "Nautic")
        == "Suunto Nautic")
    #expect(DiveComputerFamily.shearwaterPetrel.serial(deviceInfo: 0xD977_2626) == "D9772626")
    #expect(DiveComputerFamily.shearwaterPetrel.serial(deviceInfo: 0x0012_ABCD) == "0012ABCD")
    #expect(
      DiveComputerFamily.suuntoNautic.serial(advertisedIn: "Suunto Ocean 253810000400")
        == "253810000400")
    #expect(
      DiveComputerFamily.suuntoNautic.serial(advertisedIn: "Ocean 2604C3003306") == "2604C3003306")
    #expect(DiveComputerFamily.suuntoNautic.serial(advertisedIn: "Ocean") == nil)
    #expect(DiveComputerFamily.shearwaterPetrel.serial(advertisedIn: "Perdix 3") == nil)
    #expect(DiveComputerFamily.suuntoNautic.logsInstants)
    #expect(!DiveComputerFamily.shearwaterPetrel.logsInstants)
  }

  @Test func theScreensWords() {
    #expect(DiveComputerText.waitingToUpload(3) == "3 dives waiting to upload")
    #expect(DiveComputerText.alreadyWaiting(1) == "1 dive waiting to upload.")
    #expect(DiveComputerText.chooseTimeZone(1) == "Choose a time zone to import 1 dive")
    #expect(
      DiveComputerText.nothingNew(since: F.moment, in: F.helsinki)
        == "No new dives since 25 October.")
    #expect(DiveComputerText.downloading(3) == "Downloading dive 3")
    #expect(DiveComputerText.downloading(2, of: 3) == "Downloading 2 of 3 new dives")
    #expect(DiveComputerText.downloading(1, of: 1) == "Downloading 1 of 1 new dive")
    #expect(
      DiveComputerText.newOnComputer(3, of: 11) == "3 new dives out of 11 on this computer")
    #expect(DiveComputerText.newOnComputer(1, of: 11) == "1 new dive out of 11 on this computer")
    #expect(DiveComputerText.onComputer(11) == "11 dives on this computer")
    #expect(DiveComputerText.onComputer(1) == "1 dive on this computer")
    #expect(DiveComputerText.busy == "This computer is busy. The download starts when it is free.")
    #expect(
      DiveComputerText.busyContinues
        == "This computer is busy. The download continues when it is free.")
    #expect(
      DiveComputerText.busyOtherApp
        == "This computer is busy. Closing other apps that use it lets the download go on.")
    #expect(DiveComputerText.alreadyWaiting(2) == "2 dives waiting to upload.")
    #expect(DiveComputerText.couldNotDownload(1) == "1 dive couldn't be downloaded.")
    #expect(DiveComputerText.couldNotDownload(2) == "2 dives couldn't be downloaded.")
    #expect(DiveComputerText.connecting == "Connecting")
    #expect(DiveComputerText.reading == "Reading")
    #expect(DiveComputerText.subtitle(serial: nil, lastDownloaded: nil) == nil)
    #expect(
      DiveComputerText.downloaded(1, refused: 2) == "1 dive downloaded. 2 dives could not be read.")
  }

  @Test func everySentenceThatListsWhatThePhoneKeepsNamesTheDownloadHistory() throws {
    #expect(KeptText.held(ImportServer.origin).contains("dive computer download history"))
  }
}
