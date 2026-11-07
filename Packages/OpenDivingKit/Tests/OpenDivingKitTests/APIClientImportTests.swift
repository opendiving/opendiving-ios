import Foundation
import OpenDivingKit
import Synchronization
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

struct APIClientImportTests {
  private let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("APIClientImportTests-\(UUID().uuidString)", isDirectory: true)

  /// Two files on disk, one of them binary and larger than a chunk of the body writer.
  private func files() throws -> [ImportFile] {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var fit = Data((0..<(1 << 20) + 7).map { UInt8(truncatingIfNeeded: $0 &* 31) })
    fit.append(Data("\r\n--not-a-boundary\r\n".utf8))
    let fitURL = directory.appendingPathComponent("a.fit")
    try fit.write(to: fitURL)
    let uddfURL = directory.appendingPathComponent("b.uddf")
    try Data("<uddf/>".utf8).write(to: uddfURL)
    return [
      ImportFile(file: fitURL, filename: "dive-0214.fit"),
      ImportFile(
        file: uddfURL, filename: "Logbook \"Red Sea\".uddf", contentType: "application/xml"),
    ]
  }

  private func expected(_ files: [ImportFile]) throws -> [ReceivedPart] {
    try files.map {
      ReceivedPart(
        name: "file", filename: $0.filename.replacingOccurrences(of: "\"", with: "%22"),
        contentType: $0.contentType, bytes: try Data(contentsOf: $0.file))
    }
  }

  @Test func anUploadSendsTheFilesInOrderUnderTheirNames() async throws {
    let pending = try KitFixture.text("import-pending")
    let harness = ClientHarness(accessToken: "live") { _ in .json(pending, status: 201) }
    let files = try files()
    let read = try await harness.client.uploadImport(files: files)

    let requests = harness.transport.requests
    #expect(requests.map(\.route) == ["POST imports"])
    #expect(try ReceivedPart.parts(of: requests[0]) == (try expected(files)))
    #expect(requests[0].bearer == "live")
    #expect(read.status == "pending")
  }

  @Test func theFamilyReadsItsRoutes() async throws {
    let uuid = try #require(UUID(uuidString: "01a1b5d5-0182-786a-bc62-ed7fe7907b7d"))
    let path = "import/01a1b5d5-0182-786a-bc62-ed7fe7907b7d"
    let pending = try KitFixture.text("import-pending")
    let notes = try KitFixture.text("import-notes")
    let page = try KitFixture.text("imports-page")
    let harness = ClientHarness(accessToken: "live") { request in
      switch request.route {
      case "GET \(path)/notes": .json(notes)
      case "GET imports": .json(page)
      default: .json(pending)
      }
    }
    _ = try await harness.client.pendingImport()
    _ = try await harness.client.logbookImport(uuid)
    #expect(try await harness.client.importNotes(uuid).dives.count == 2)
    #expect(try await harness.client.imports(page: 2).data.count == 2)
    let requests = harness.transport.requests
    #expect(requests.map(\.route) == ["GET imports/pending", "GET \(path)", "GET \(path)/notes", "GET imports"])
    #expect(requests[3].url?.query?.contains("page=2") == true)
  }

  @Test func theApplyCarriesTheDiversAnswersAndNoFiles() async throws {
    let applied = try KitFixture.text("import-applied")
    let harness = ClientHarness(accessToken: "live") { _ in .json(applied) }
    let uuid = UUID()
    _ = try await harness.client.applyImport(
      uuid,
      LogbookImportApply(
        checkInDetails: ImportCheckInSubmission(email: .value("desk@example.org"), phone: .null),
        portrait: ImportPortraitChoice(take: false, accountSha256: nil)))
    let request = try #require(harness.transport.requests.first)
    #expect(request.route == "POST import/\(uuid.uuidString.lowercased())/apply")
    #expect(
      try JSONValue.parse(try #require(request.httpBody))
        == JSONValue.parse(
          Data(
            #"""
            {"check_in_details":{"email":"desk@example.org","phone":null},
             "portrait":{"choice":"keep","account_sha256":null}}
            """#.utf8)))
  }

  @Test func theApplySendsNothingTheDiverDidNotAnswer() async throws {
    let applied = try KitFixture.text("import-applied")
    let harness = ClientHarness(accessToken: "live") { _ in .json(applied) }
    _ = try await harness.client.applyImport(UUID(), LogbookImportApply())
    let body = try #require(harness.transport.requests.first?.httpBody)
    #expect(try JSONValue.parse(body) == JSONValue.parse(Data("{}".utf8)))
  }

  @Test func aDeleteNamesTheStatusItMeans() async throws {
    let harness = ClientHarness(accessToken: "live") { _ in
      StubTransport.Response(status: 204, body: Data())
    }
    let uuid = UUID()
    try await harness.client.deleteImport(uuid, status: "pending")
    let request = try #require(harness.transport.requests.first)
    #expect(request.route == "DELETE import/\(uuid.uuidString.lowercased())")
    #expect(request.url?.query == "status=pending")
  }

  @Test func theBodyGoesUpFromAFileAndTheFileIsGoneAfterwards() async throws {
    let transport = FileOnlyTransport(answer: try KitFixture.data("import-pending"))
    let client = APIClient(
      origin: ClientHarness.origin, transport: transport,
      secrets: InMemorySecretStore([ClientHarness.origin.description: "refresh-0"]),
      background: NoBackgroundExecution(), userAgent: ClientHarness.userAgent,
      accessToken: "live")
    _ = try await client.uploadImport(files: try files())
    let upload = try #require(transport.uploads.first)
    #expect(transport.uploads.count == 1)
    #expect(upload.hadBody == false)
    #expect(upload.fileExisted)
    #expect(upload.fileSize > 1 << 20)
    #expect(!FileManager.default.fileExists(atPath: upload.file.path))
  }

  @Test func aRefusedImportIsTheAPIsSentence() async throws {
    let harness = ClientHarness(accessToken: "live") { _ in
      .json(#"{"detail":"No reader here claims these bytes."}"#, status: 415)
    }
    await #expect(
      throws: APIError.http(status: 415, message: "No reader here claims these bytes.")
    ) { try await harness.client.uploadImport(files: try files()) }
  }
}

/// A transport that refuses to send a body held in memory, and records what each upload saw
/// of the file it was handed.
private final class FileOnlyTransport: HTTPTransport {
  struct Upload {
    let file: URL
    let hadBody: Bool
    let fileExisted: Bool
    let fileSize: Int
  }

  private let answer: Data
  private let recorded = Mutex<[Upload]>([])

  init(answer: Data) {
    self.answer = answer
  }

  var uploads: [Upload] { recorded.withLock { $0 } }

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    Issue.record("A multipart body was sent from memory")
    throw URLError(.cancelled)
  }

  func upload(_ request: URLRequest, fromFile file: URL) async throws -> (Data, HTTPURLResponse) {
    let size = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int) ?? 0
    recorded.withLock {
      $0.append(
        Upload(
          file: file, hadBody: request.httpBody != nil,
          fileExisted: FileManager.default.fileExists(atPath: file.path), fileSize: size))
    }
    return (
      answer,
      HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    )
  }
}
