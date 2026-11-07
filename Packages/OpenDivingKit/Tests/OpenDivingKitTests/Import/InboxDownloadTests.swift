import Foundation
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// What the inbox does differently for a download archive, the only copy of its dives until
/// they are imported.
@MainActor
struct InboxDownloadTests {
  private let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("InboxDownloadTests-\(UUID().uuidString)", isDirectory: true)
  private let shared = SharedFiles()

  private func loaded(_ server: ImportServer) async throws -> InboxModel {
    let session = Session(
      transport: server,
      secrets: InMemorySecretStore([ImportServer.origin.description: "refresh"]),
      activeOrigin: InMemoryActiveOriginStore(ImportServer.origin),
      background: NoBackgroundExecution(), connectivity: AlwaysReachable(),
      applicationSupport: root, userAgent: ClientHarness.userAgent, accessToken: "live")
    try await session.loadAccount()
    let model = InboxModel(session: session)
    model.sessionChanged()
    return model
  }

  private let download = InboxDownload(
    computers: [
      .init(
        family: .shearwaterPetrel, vendor: "Shearwater", product: "Perdix 3", serial: "D9772626",
        dives: 12)
    ], downloadedAt: DiveComputerFixtures.moment)

  private let archive = "shearwater-perdix-3_D9772626_2026-10-25T0920.zip"

  @Test func anAppliedImportKeepsARefusedDownloadToGoUpAloneAndDropsARefusedSharedFile() async throws {
    let server = try ImportServer()
    server.refuse(parts: [0, 1])
    let model = try await loaded(server)
    model.receive([try shared.make(archive)], moving: true, download: download)
    model.receive([try shared.make("opendiving-export.zip")], moving: true)
    model.upload()
    await model.settled()
    #expect(server.uploads == [[archive, "opendiving-export.zip"]])

    model.apply(ImportCheckInChoices())
    await model.settled()

    #expect(model.files.map(\.filename) == [archive])
    #expect(model.files.first?.download == download)
    #expect(model.files.first?.uploadedInto == nil)
    #expect(model.result != nil)

    server.refuse(parts: [])
    model.upload()
    await model.settled()
    #expect(server.uploads.last == [archive])
  }

  @Test func anApplySeenFromElsewhereKeepsARefusedDownloadToo() async throws {
    let server = try ImportServer()
    server.refuse(parts: [1])
    let model = try await loaded(server)
    model.receive([try shared.make("first.zip")], moving: true, download: download)
    model.receive([try shared.make("second.zip")], moving: true, download: download)
    model.upload()
    await model.settled()
    server.applyElsewhere()

    model.readPending()
    await model.settled()

    #expect(model.files.map(\.filename) == ["second.zip"])
    #expect(model.files.first?.uploadedInto == nil)
  }

  @Test func aDownloadTheImportReadLeavesLikeAnyFile() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    model.receive([try shared.make("a.zip")], moving: true, download: download)
    model.upload()
    await model.settled()
    #expect(model.files.count == 1)

    model.apply(ImportCheckInChoices())
    await model.settled()
    #expect(model.files.isEmpty)
  }

  @Test func theListsTellTheWalkAndTheUnionApart() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    model.receive([try shared.make("uploaded.zip")], moving: true, download: download)
    model.upload()
    await model.settled()
    model.receive([try shared.make("waiting.zip")], moving: true, download: download)
    model.receive([try shared.make("shared.fit")], moving: true)

    #expect(model.keptDownloads(marked: false).map(\.filename) == ["uploaded.zip", "waiting.zip"])
    #expect(model.unitableDownloads(marked: false).map(\.filename) == ["waiting.zip"])
  }

  @Test func aSwapNeverTakesAnArchiveAnUploadTookInTheMeantime() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    model.receive([try shared.make("a.zip")], moving: true, download: download)
    let waiting = model.unitableDownloads(marked: false)
    model.upload()
    await model.settled()

    let union = try shared.make("union.zip")
    #expect(model.replaceDownloads(waiting, with: union, download: download) == nil)
    #expect(model.files.map(\.filename) == ["a.zip"])
  }

  @Test func onlyADownloadAsksBeforeItIsRemoved() async throws {
    let model = try await loaded(try ImportServer())
    model.receive([try shared.make("a.fit")], moving: true)
    #expect(!model.removeAllNeedsConfirmation)
    #expect(!model.removalNeedsConfirmation(try #require(model.files.first)))
    model.receive([try shared.make("b.zip")], moving: true, download: download)
    #expect(model.removeAllNeedsConfirmation)
  }
}
