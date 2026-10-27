import Foundation
import Testing

@testable import OpenDivingKit

/// Where the remembered computers live, what survives what, and the Settings list over them.
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

  @Test func aRecordIsOneFileInTheAccountsDirectoryFoundByFamilyAndSerialInEitherCase() throws {
    try store.save(DiveComputerRecord(identity: F.perdix, fingerprint: F.fingerprint(3)))
    #expect(
      try FileManager.default.contentsOfDirectory(atPath: folder.path) == [
        "shearwater-petrel_D9772626.json"
      ])
    #expect(
      store.record(family: .shearwaterPetrel, serial: "d9772626")?.fingerprint == F.fingerprint(3))
    #expect(store.record(family: .suuntoNautic, serial: "D9772626") == nil)
  }

  @Test func aFileThisBuildCannotReadIsKeptAndNeverOverwritten() throws {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let unreadable = folder.appendingPathComponent("shearwater-petrel_D9772626.json")
    try Data(#"{"family": 7}"#.utf8).write(to: unreadable)
    try store.save(DiveComputerRecord(identity: F.ocean))

    #expect(store.records().map(\.serial) == ["253810000400"])
    #expect(store.unreadableCount == 1)
    #expect(throws: DiveComputerStoreError.unreadableRecord) {
      try store.save(DiveComputerRecord(identity: F.perdix))
    }
    #expect(try Data(contentsOf: unreadable) == Data(#"{"family": 7}"#.utf8))
  }

  @Test func forgettingTheServerRemovesThemAndSignOutLeavesThem() throws {
    try store.save(DiveComputerRecord(identity: F.perdix))
    try stateStore.endSession(for: ImportServer.origin)
    #expect(store.records().count == 1)
    try stateStore.forget(ImportServer.origin)
    #expect(store.records().isEmpty)
  }

  @Test func theSettingsListForgetsAsksForEverythingAndSetsTheDiversZone() async throws {
    let server = try ImportServer()
    let session = Session(
      transport: server,
      secrets: InMemorySecretStore([ImportServer.origin.description: "refresh"]),
      activeOrigin: InMemoryActiveOriginStore(ImportServer.origin),
      background: NoBackgroundExecution(), applicationSupport: root,
      userAgent: ClientHarness.userAgent, accessToken: "live")
    try await session.loadAccount()
    try store.save(
      DiveComputerRecord(
        identity: F.perdix, fingerprint: F.fingerprint(3), lastDownloaded: F.moment))
    try store.save(DiveComputerRecord(identity: F.ocean, watchZone: F.helsinki))

    let list = DiveComputersListModel(session: session, zone: F.helsinki)
    #expect(list.computers.map(\.title) == ["Shearwater Perdix 3", "Suunto Ocean"])
    let perdix = list.computers[0]
    #expect(list.subtitle(perdix) == "Serial D9772626 · Last downloaded 25 October")
    #expect(DiveComputerText.forgetTitle(perdix) == "Forget Perdix 3?")

    list.downloadAllNextTime(perdix)
    let flagged = try #require(store.record(family: .shearwaterPetrel, serial: "D9772626"))
    #expect(flagged.downloadAllNextTime)
    #expect(flagged.fingerprintToSet == nil)
    #expect(flagged.fingerprint == F.fingerprint(3))

    let ocean = list.computers[1]
    #expect(ocean.zone == F.helsinki)
    let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
    list.setDiverZone(tokyo, for: ocean)
    #expect(list.computers[1].zone == tokyo)
    list.setDiverZone(nil, for: list.computers[1])
    #expect(list.computers[1].zone == F.helsinki)

    list.forget(perdix)
    #expect(list.computers.map(\.title) == ["Suunto Ocean"])
    list.forget(list.computers[0])
    #expect(list.computers.isEmpty)
    #expect(
      DiveComputerText.emptyList == "No dive computers yet. Connect one with + on the Dives tab.")
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
    let union = InboxDownload(
      computers: [
        .init(
          family: .shearwaterPetrel, vendor: "Shearwater", product: "Perdix 3", serial: "D9772626",
          dives: 12),
        .init(
          family: .suuntoNautic, vendor: "Suunto", product: "Ocean", serial: "253810000400",
          dives: 2),
      ], downloadedAt: F.moment)
    #expect(
      DiveComputerText.inboxRow(union, in: F.helsinki)
        == "14 dives from Shearwater Perdix 3 and Suunto Ocean, downloaded 25 October")
    #expect(
      DiveComputerText.nothingNew(since: F.moment, in: F.helsinki)
        == "No new dives since 25 October.")
    #expect(DiveComputerText.downloading(3) == "Downloading dive 3")
    #expect(DiveComputerText.subtitle(serial: nil, lastDownloaded: nil) == nil)
    #expect(
      DiveComputerText.downloaded(1, refused: 2) == "1 dive downloaded. 2 dives could not be read.")
  }

  @Test func everySentenceThatListsWhatThePhoneKeepsNamesTheComputers() throws {
    let origin = ImportServer.origin
    for sentence in [
      KeptText.signedOutFooter, KeptText.settingsFooter, KeptText.held(origin),
      KeptText.forgetMessage(OutboxSummary()), KeptText.forgotten(origin),
    ] {
      #expect(sentence.contains("dive computers"))
    }
  }
}
