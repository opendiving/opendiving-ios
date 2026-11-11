import Foundation
import OpenDivingKit
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// *Preferences*' tags: the list, the rename in the row and the delete.
@MainActor
struct TagsModelTests {
  private let origin = ClientHarness.origin
  private let night = "01a0b7c2-4f1e-7a3b-9c2d-1e5f6a7b8c90"

  private func model(
    _ server: SettingsServer, connectivity: SettingsConnectivity = SettingsConnectivity()
  ) async throws -> TagsModel {
    let session = Session(
      transport: server, secrets: InMemorySecretStore([origin.description: "refresh-0"]),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      connectivity: connectivity,
      applicationSupport: FileManager.default.temporaryDirectory
        .appendingPathComponent("TagsModelTests-\(UUID().uuidString)", isDirectory: true),
      userAgent: ClientHarness.userAgent)
    try await session.loadAccount()
    return TagsModel(session: session)
  }

  private func tagWrites(_ server: SettingsServer) -> [String] {
    server.requests.map(\.route).filter { !$0.hasPrefix("GET") && $0.contains("tag/") }
  }

  @Test func theTagsAreListedWithTheirCounts() async throws {
    let model = try await model(try SettingsServer())
    #expect(model.tags == nil)
    await model.load()
    #expect(model.tags?.map(\.name) == ["night", "wall"])
    #expect(model.tags.map { $0.map(TagsModel.usage) } == ["12 dives", "1 dive, 2 sites"])
  }

  @Test func withNoRouteTheListSaysSoAndReadsOnceOneAppears() async throws {
    let server = try SettingsServer()
    let connectivity = SettingsConnectivity()
    let model = try await model(server, connectivity: connectivity)
    connectivity.isRouteAvailable = false
    await model.load()
    #expect(model.tags == nil)
    #expect(model.loadFailure == APIError.noRoute.message)
    #expect(!server.requests.contains { $0.route == "GET tags" })

    let following = Task { await model.followRoute() }
    while !connectivity.isFollowed { await Task.yield() }
    connectivity.appear()
    while model.tags == nil { await Task.yield() }
    following.cancel()
    await following.value
    #expect(model.loadFailure == nil)
  }

  @Test func aRenameSendsTheTrimmedNameAndTheListReadsAgain() async throws {
    let server = try SettingsServer()
    let model = try await model(server)
    await model.load()
    let tag = try #require(model.tags?.first)

    model.rename.begin(tag.uuid, name: tag.name)
    model.rename.draft = "  night dive "
    await model.saveRename()

    #expect(tagWrites(server) == ["PATCH tag/\(night)"])
    let rename = server.requests.first { $0.route == "PATCH tag/\(night)" }
    #expect(rename?.json == (try JSONValue.parse(Data(#"{"name":"night dive"}"#.utf8))))
    #expect(model.rename.editing == nil)
    #expect(model.tags?.first?.name == "night dive")
  }

  @Test func anEmptyNameCannotBeSavedAndAnUnchangedOneSendsNothing() async throws {
    let server = try SettingsServer()
    let model = try await model(server)
    await model.load()
    let tag = try #require(model.tags?.first)

    model.rename.begin(tag.uuid, name: tag.name)
    model.rename.draft = "   "
    #expect(!model.rename.canSave)
    await model.saveRename()
    #expect(model.rename.editing == tag.uuid)

    model.rename.draft = String(repeating: "a", count: DiveFormBounds.tagMax + 1)
    #expect(!model.rename.canSave)

    model.rename.draft = " night "
    await model.saveRename()
    #expect(model.rename.editing == nil)
    #expect(tagWrites(server).isEmpty)
  }

  @Test func aRefusedRenameKeepsTheRowOpenWithTheAPIsSentence() async throws {
    let server = try SettingsServer()
    let model = try await model(server)
    await model.load()
    let tag = try #require(model.tags?.first)
    server.fail(
      "PATCH tag/\(night)",
      with: .json(#"{"detail":"A tag with this name already exists"}"#, status: 422))

    model.rename.begin(tag.uuid, name: tag.name)
    model.rename.draft = "wall"
    await model.saveRename()

    #expect(model.rename.failure == "A tag with this name already exists")
    #expect(model.rename.editing == tag.uuid)
    #expect(model.rename.draft == "wall")
  }

  @Test func aDeleteWaitsForItsConfirmationAndTheListReadsAgain() async throws {
    let server = try SettingsServer()
    let model = try await model(server)
    await model.load()
    let tag = try #require(model.tags?.first)

    // Dismissed without confirming.
    model.confirmingDelete = tag
    model.confirmingDelete = nil
    #expect(tagWrites(server).isEmpty)

    // Confirmed: the dialog clears what it presents as it closes, then its button runs.
    model.confirmingDelete = tag
    model.confirmingDelete = nil
    await model.confirmDelete(tag)
    #expect(tagWrites(server) == ["DELETE tag/\(night)"])
    #expect(model.tags?.map(\.name) == ["wall"])
    #expect(model.deleteFailure == nil)
  }

  @Test func offlineARenameIsNotSent() async throws {
    let server = try SettingsServer()
    let connectivity = SettingsConnectivity()
    let model = try await model(server, connectivity: connectivity)
    await model.load()
    let tag = try #require(model.tags?.first)
    connectivity.isRouteAvailable = false

    model.rename.begin(tag.uuid, name: tag.name)
    model.rename.draft = "dusk"
    await model.saveRename()

    #expect(tagWrites(server).isEmpty)
    #expect(model.rename.failure == APIError.noRoute.message)
  }
}
