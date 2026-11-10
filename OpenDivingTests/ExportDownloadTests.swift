import Foundation
import OpenDivingKit
import Testing

@testable import OpenDiving

/// An export over a real `URLSession`, with the answer stubbed beneath it: the body lands in a
/// file through the session's download task.
@MainActor
struct ExportDownloadTests {
  @Test func theArchiveIsWrittenToAFileOfItsOwn() async throws {
    let origin = try #require(ServerOrigin("https://export-\(UUID().uuidString.prefix(8)).invalid"))
    let configuration = NetworkConfiguration.make()
    configuration.protocolClasses = [StubURLProtocol.self] + (configuration.protocolClasses ?? [])
    let client = APIClient(
      origin: origin, transport: URLSessionTransport(configuration: configuration),
      secrets: InMemorySecretStore(), background: NoBackgroundExecution(), userAgent: .device,
      accessToken: "access-1")
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("ExportDownloadTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let file = try await client.export(.archive, into: directory)
    #expect(file.url.lastPathComponent == "opendiving-export.zip")
    #expect(try Data(contentsOf: file.url) == Data([0x52, 0x49, 0x46, 0x46]))
    file.remove()
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
  }
}
