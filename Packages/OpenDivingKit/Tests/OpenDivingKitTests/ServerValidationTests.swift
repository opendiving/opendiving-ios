import Foundation
import OpenDivingKit
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

struct ServerValidationTests {
  private func validate(config: StubTransport.Response) async throws -> ServerInfo {
    let health = try KitFixture.text("health")
    let harness = ClientHarness { request in
      request.route == "GET health" ? .json(health) : config
    }
    return try await harness.client.instance()
  }

  @Test func readsAValidInstanceAndTheBuildItRuns() async throws {
    let info = try await validate(config: .json(try KitFixture.text("config")))
    #expect(info.config.registrationMode == "invite")
    #expect(info.config.projectOperated)
    #expect(info.health?.version == "0.6.0")
    #expect(info.health?.commit == "unknown")
  }

  @Test func acceptsAConfigThatGrewAKey() async throws {
    let info = try await validate(
      config: .json(
        #"{"registration_mode":"open","project_operated":false,"join_links":true,"#
          + #""map_tiles":false,"something_new":{"nested":[1,2]}}"#))
    #expect(info.config.registrationMode == "open")
  }

  @Test func acceptsAnOlderConfigWithTheTwoKeysAlone() async throws {
    let info = try await validate(
      config: .json(#"{"registration_mode":"invite","project_operated":true}"#))
    #expect(info.config.joinLinks == nil)
  }

  @Test func htmlIsNotAnInstance() async {
    await #expect(throws: APIError.notAnInstance) {
      try await validate(
        config: StubTransport.Response(
          headers: ["Content-Type": "text/html"], body: Data("<html>Hello</html>".utf8)))
    }
  }

  @Test func aNotFoundIsNotAnInstance() async {
    await #expect(throws: APIError.notAnInstance) {
      try await validate(config: .json(#"{"detail":"Not Found"}"#, status: 404))
    }
  }

  @Test func jsonMissingTheTwoKeysIsNotAnInstance() async {
    await #expect(throws: APIError.notAnInstance) {
      try await validate(config: .json(#"{"registration_mode":"open"}"#))
    }
  }

  @Test func noAnswerIsUnreachableAfterOneRequest() async throws {
    let harness = ClientHarness { _ in throw URLError(.cannotConnectToHost) }
    do {
      _ = try await harness.client.instance()
      Issue.record("Expected the server to be unreachable")
    } catch let APIError.unreachable(failure) {
      #expect(failure.code == URLError.Code.cannotConnectToHost.rawValue)
    }
    #expect(harness.transport.requests.count == 1)
  }
}
