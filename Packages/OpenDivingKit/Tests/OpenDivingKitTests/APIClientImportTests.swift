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

  @Test func thePreviewAndTheApplySendTheSameFilesInTheSameOrderUnderTheSameNames() async throws {
    let preview = try KitFixture.text("import-preview")
    let result = try KitFixture.text("import-result")
    let harness = ClientHarness(accessToken: "live") { request in
      request.route == "POST import/logbook/preview" ? .json(preview) : .json(result)
    }
    let files = try files()
    let read = try await harness.client.importPreview(files: files)
    _ = try await harness.client.importApply(files: files, token: read.token)

    let requests = harness.transport.requests
    #expect(requests.map(\.route) == ["POST import/logbook/preview", "POST import/logbook"])
    let previewParts = try ReceivedPart.parts(of: requests[0])
    let applyParts = try ReceivedPart.parts(of: requests[1])
    #expect(previewParts == (try expected(files)))
    #expect(
      applyParts.first
        == ReceivedPart(
          name: "token", filename: nil, contentType: nil, bytes: Data(read.token.utf8)))
    #expect(Array(applyParts.dropFirst()) == previewParts)
    #expect(requests[0].bearer == "live")
  }

  @Test func theApplyCarriesTheDiversAnswersWhenGiven() async throws {
    let harness = ClientHarness(accessToken: "live") { _ in
      .json(try KitFixture.text("import-result"))
    }
    _ = try await harness.client.importApply(
      files: try files(), token: "t",
      checkInDetails: ImportCheckInSubmission(email: .value("desk@example.org"), phone: .null),
      portrait: ImportPortraitChoice(take: false, accountSha256: nil))
    let parts = try ReceivedPart.parts(of: try #require(harness.transport.requests.first))
    #expect(parts.map(\.name) == ["token", "check_in_details", "portrait", "file", "file"])
    #expect(
      try JSONValue.parse(parts[1].bytes)
        == JSONValue.parse(Data(#"{"email":"desk@example.org","phone":null}"#.utf8)))
    #expect(
      try JSONValue.parse(parts[2].bytes)
        == JSONValue.parse(Data(#"{"choice":"keep","account_sha256":null}"#.utf8)))
  }

  @Test func theBodyGoesUpFromAFileAndTheFileIsGoneAfterwards() async throws {
    let transport = FileOnlyTransport(answer: try KitFixture.data("import-preview"))
    let client = APIClient(
      origin: ClientHarness.origin, transport: transport,
      secrets: InMemorySecretStore([ClientHarness.origin.description: "refresh-0"]),
      background: NoBackgroundExecution(), userAgent: ClientHarness.userAgent,
      accessToken: "live")
    _ = try await client.importPreview(files: try files())
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
    ) { try await harness.client.importPreview(files: try files()) }
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
