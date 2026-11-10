import Foundation
import OpenDivingKit
import Testing

/// *Data*'s storage: the read and what it prints.
@MainActor
struct StorageModelTests {
  private let origin = ClientHarness.origin

  private func model(
    _ server: SettingsServer, connectivity: SettingsConnectivity = SettingsConnectivity()
  ) async throws -> StorageModel {
    let session = Session(
      transport: server, secrets: InMemorySecretStore([origin.description: "refresh-0"]),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      connectivity: connectivity,
      applicationSupport: FileManager.default.temporaryDirectory
        .appendingPathComponent("StorageModelTests-\(UUID().uuidString)", isDirectory: true),
      userAgent: ClientHarness.userAgent)
    try await session.loadAccount()
    return StorageModel(session: session)
  }

  private func usage(limit: Int?, used: Int = 137_512_960, files: Int = 12) throws
    -> StorageUsageRead
  {
    var object =
      try JSONSerialization.jsonObject(with: KitFixture.data("storage")) as! [String: Any]
    object["limit_bytes"] = limit ?? NSNull()
    object["used_bytes"] = used
    object["dive_files_count"] = files
    return try APICoding.decoder().decode(
      StorageUsageRead.self, from: JSONSerialization.data(withJSONObject: object))
  }

  @Test func theUsageIsRead() async throws {
    let model = try await model(try SettingsServer())
    await model.load()
    #expect(model.usage?.divesWithFilesCount == 9)
    #expect(model.loadFailure == nil)
  }

  @Test func withNoRouteNothingIsAskedForAndARouteReadsAgain() async throws {
    let server = try SettingsServer()
    let connectivity = SettingsConnectivity()
    let model = try await model(server, connectivity: connectivity)
    connectivity.isRouteAvailable = false
    await model.load()
    #expect(model.usage == nil)
    #expect(model.loadFailure == APIError.noRoute.message)
    #expect(!server.requests.contains { $0.route == "GET user/storage" })

    let following = Task { await model.followRoute() }
    while !connectivity.isFollowed { await Task.yield() }
    connectivity.appear()
    while model.usage == nil { await Task.yield() }
    following.cancel()
    await following.value
    #expect(model.loadFailure == nil)
  }

  @Test func aRefusalIsTheAPIsSentence() async throws {
    let server = try SettingsServer()
    server.fail("GET user/storage", with: .json(#"{"detail":"Not today"}"#, status: 503))
    let model = try await model(server)
    await model.load()
    #expect(model.loadFailure == "Not today")
  }

  @Test func usedAgainstTheLimitAndTheKinds() throws {
    let usage = try usage(limit: 1_073_741_824)
    #expect(StorageText.used(usage) == "131.1 MB of 1.0 GB used")
    #expect(!StorageText.isOverLimit(usage))
    #expect(
      StorageText.kinds(usage) == [
        .init(label: "Dive-computer files", size: "71.4 MB", attached: "12 files on 9 dives"),
        .init(
          label: "Certification cards", size: "50.0 MB", attached: "4 files on 2 certifications"),
        .init(label: "Profile picture and portrait", size: "9.8 MB", attached: nil),
      ])
  }

  @Test func noLimitPrintsTheUsedAlone() throws {
    let usage = try usage(limit: nil)
    #expect(StorageText.used(usage) == "131.1 MB used")
    #expect(!StorageText.isOverLimit(usage))
  }

  @Test func overTheLimitIsSaid() throws {
    #expect(StorageText.isOverLimit(try usage(limit: 1024, used: 2048)))
  }

  @Test func noFilesAttachNothing() throws {
    #expect(StorageText.kinds(try usage(limit: nil, files: 0)).first?.attached == nil)
  }
}
