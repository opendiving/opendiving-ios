import Foundation
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The server's word on which experimental features it switches on.
@MainActor
struct ExperimentalFeaturesTests {
  private func session(config: StubTransport.Response) throws -> Session {
    let health = try KitFixture.text("health")
    return Session.stub(
      transport: StubTransport(routes: ["GET config": config, "GET health": .json(health)]))
  }

  @Test func offUntilTheServerHasAnswered() throws {
    let session = try session(
      config: .json(try KitFixture.text("config-experimental-features-all")))
    #expect(!session.isExperimentalFeatureOn("dive-planner"))
  }

  @Test func offOnAConfigThatDoesNotSay() async throws {
    let session = try session(config: .json(try KitFixture.text("config")))
    await session.loadServerInfo()
    #expect(session.server != nil)
    #expect(!session.isExperimentalFeatureOn("dive-planner"))
  }

  @Test func offWhenTheConfigCannotBeFetched() async throws {
    let session = try session(config: StubTransport.Response(status: 503))
    await session.loadServerInfo()
    #expect(session.server == nil)
    #expect(!session.isExperimentalFeatureOn("dive-planner"))
  }

  @Test func onOnlyForTheNamesTheServerLists() async throws {
    let session = try session(config: .json(try KitFixture.text("config-experimental-features")))
    await session.loadServerInfo()
    #expect(session.isExperimentalFeatureOn("dive-planner"))
    #expect(session.isExperimentalFeatureOn("trip-sharing"))
    #expect(!session.isExperimentalFeatureOn("dive"))
    #expect(!session.isExperimentalFeatureOn("all"))
  }

  @Test func allSwitchesOnEveryName() async throws {
    let session = try session(
      config: .json(try KitFixture.text("config-experimental-features-all")))
    await session.loadServerInfo()
    #expect(session.isExperimentalFeatureOn("dive-planner"))
    #expect(session.isExperimentalFeatureOn("any-name"))
  }

  @Test func anEmptyListSwitchesNothingOn() async throws {
    let config = try KitFixture.text("config-experimental-features").replacingOccurrences(
      of: #"["dive-planner", "trip-sharing"]"#, with: "[]")
    #expect(config.contains(#""experimental_features": []"#))
    let session = try session(config: .json(config))
    await session.loadServerInfo()
    #expect(session.server?.config.experimentalFeatures == [])
    #expect(!session.isExperimentalFeatureOn("dive-planner"))
  }
}
