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

  /// `import-result.json` with each part's own row refused or read as `refused` says.
  private func result(refused: [Bool]) throws -> String {
    var json = try #require(
      try JSONSerialization.jsonObject(with: KitFixture.data("import-result")) as? [String: Any])
    json["members"] = refused.enumerated().map { part, refused in
      [
        "part": part, "container": NSNull(), "name": "file-\(part)", "byte_size": 1,
        "sha256": String(repeating: "0", count: 64), "format": refused ? NSNull() : "divejson",
        "opened": NSNull(), "kept": false, "not_kept": NSNull(),
        "refusal": refused
          ? "This is a second full-export archive, and one import restores one. Import it on its own."
          : NSNull(),
      ] as [String: Any]
    }
    return String(decoding: try JSONSerialization.data(withJSONObject: json), as: UTF8.self)
  }

  @Test func theApplyKeepsARefusedDownloadToReadAloneAndDiscardsARefusedSharedFile() async throws {
    let server = try ImportServer()
    let answer = try result(refused: [true, true])
    server.answerApply { .json(answer) }
    let model = try await loaded(server)
    model.receive(
      [try shared.make("shearwater-perdix-3_D9772626_2026-10-25T0920.zip")], moving: true,
      download: download)
    await model.settled()
    model.receive([try shared.make("opendiving-export.zip")], moving: true)
    await model.settled()
    model.readAgain()
    await model.settled()
    #expect(
      server.previews.last
        == ["shearwater-perdix-3_D9772626_2026-10-25T0920.zip", "opendiving-export.zip"])

    model.apply(ImportCheckInChoices())
    await model.settled()

    #expect(model.files.map(\.filename) == ["shearwater-perdix-3_D9772626_2026-10-25T0920.zip"])
    #expect(model.files.first?.download == download)
    #expect(model.result != nil)
    #expect(server.previews.last == ["shearwater-perdix-3_D9772626_2026-10-25T0920.zip"])
  }

  @Test func aDownloadTheImportReadIsDiscardedLikeAnyFile() async throws {
    let server = try ImportServer()
    let answer = try result(refused: [false])
    server.answerApply { .json(answer) }
    let model = try await loaded(server)
    model.receive([try shared.make("a.zip")], moving: true, download: download)
    await model.settled()
    model.apply(ImportCheckInChoices())
    await model.settled()
    #expect(model.files.isEmpty)
    #expect(server.previews.count == 1)
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
