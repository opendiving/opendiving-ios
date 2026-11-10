import Foundation
import OpenDivingKit
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// *Data*'s downloads: the request, the file's name and its removal.
@MainActor
struct DataExportModelTests {
  private let origin = ClientHarness.origin
  private let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("DataExportModelTests-\(UUID().uuidString)", isDirectory: true)

  private func model(
    _ server: SettingsServer, connectivity: SettingsConnectivity = SettingsConnectivity()
  ) async throws -> DataExportModel {
    let session = Session(
      transport: server, secrets: InMemorySecretStore([origin.description: "refresh-0"]),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      connectivity: connectivity,
      applicationSupport: FileManager.default.temporaryDirectory
        .appendingPathComponent("DataExportModelTests-\(UUID().uuidString)", isDirectory: true),
      userAgent: ClientHarness.userAgent)
    try await session.loadAccount()
    return DataExportModel(session: session, directory: directory)
  }

  private func exports(_ server: SettingsServer) -> [URLRequest] {
    server.requests.filter { $0.route.hasPrefix("GET export/") }
  }

  /// Every file left under the model's directory.
  private func leftovers() -> [String] {
    let enumerator = FileManager.default.enumerator(atPath: directory.path)
    return (enumerator?.allObjects as? [String]) ?? []
  }

  @Test func eachFormatIsItsOwnRouteWithTheBearer() async throws {
    let server = try SettingsServer()
    let model = try await model(server)
    for format in ExportFormat.allCases {
      await model.download(format)
      model.finishSharing()
    }
    #expect(
      exports(server).map(\.route) == [
        "GET export/divejson", "GET export/uddf", "GET export/csv", "GET export/archive",
      ])
    #expect(
      exports(server).allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer fresh" }
    )
  }

  @Test func theFileCarriesTheServersNameAndTheBody() async throws {
    let model = try await model(try SettingsServer())
    await model.download(.archive)
    let file = try #require(model.shared)
    #expect(file.url.lastPathComponent == "opendiving-diver-20261110.zip")
    #expect(try String(contentsOf: file.url, encoding: .utf8) == "the archive export")
    #expect(model.downloading == nil)
    #expect(model.failure == nil)
  }

  @Test func closingTheShareSheetLeavesNoCopy() async throws {
    let model = try await model(try SettingsServer())
    await model.download(.divejson)
    let file = try #require(model.shared)
    #expect(FileManager.default.fileExists(atPath: file.url.path))
    model.finishSharing()
    #expect(model.shared == nil)
    #expect(!FileManager.default.fileExists(atPath: file.url.path))
    #expect(leftovers().isEmpty)
  }

  @Test func leavingTheScreenRemovesTheFileWaiting() async throws {
    let model = try await model(try SettingsServer())
    await model.download(.csv)
    #expect(model.shared != nil)
    model.stop()
    #expect(model.shared == nil)
    #expect(leftovers().isEmpty)
  }

  @Test func noExportStartsWhileOneWaitsInTheShareSheet() async throws {
    let server = try SettingsServer()
    let model = try await model(server)
    await model.download(.uddf)
    await model.download(.archive)
    #expect(exports(server).map(\.route) == ["GET export/uddf"])
    #expect(model.isBusy)
  }

  @Test func withNoRouteNothingIsSentAndTheRowSaysSo() async throws {
    let server = try SettingsServer()
    let connectivity = SettingsConnectivity()
    let model = try await model(server, connectivity: connectivity)
    connectivity.isRouteAvailable = false
    await model.download(.archive)
    #expect(exports(server).isEmpty)
    #expect(model.shared == nil)
    #expect(model.failure?.format == .archive)
    #expect(model.failure?.message == APIError.noRoute.message)
  }

  @Test func theHourlyLimitIsTheAPIsSentenceAndLeavesNoFile() async throws {
    let server = try SettingsServer()
    server.fail(
      "GET export/archive",
      with: .json(#"{"detail":"Too many requests. Please try again later."}"#, status: 429))
    let model = try await model(server)
    await model.download(.archive)
    #expect(model.shared == nil)
    #expect(model.failure?.format == .archive)
    #expect(model.failure?.message == "Too many requests. Please try again later.")
    #expect(leftovers().isEmpty)

    server.succeed("GET export/archive")
    await model.download(.archive)
    #expect(model.failure == nil)
    #expect(model.shared != nil)
  }

  @Test(arguments: [
    (#"attachment; filename="../../etc/passwd""#, "passwd"),
    (#"attachment; filename*=UTF-8''dive%20log.zip; filename="dive.zip""#, "dive log.zip"),
    ("attachment; filename=plain.csv", "plain.csv"),
    (#"attachment; filename="..""#, "opendiving-export.zip"),
    ("attachment", "opendiving-export.zip"),
  ])
  func theNameIsOneComponentOrTheFallback(header: String, name: String) async throws {
    let server = try SettingsServer()
    server.fail(
      "GET export/archive",
      with: StubTransport.Response(
        headers: ["Content-Disposition": header], body: Data("zip".utf8)))
    let model = try await model(server)
    await model.download(.archive)
    let file = try #require(model.shared)
    #expect(file.url.lastPathComponent == name)
    #expect(file.url.deletingLastPathComponent().deletingLastPathComponent() == directory)
    model.finishSharing()
  }
}
