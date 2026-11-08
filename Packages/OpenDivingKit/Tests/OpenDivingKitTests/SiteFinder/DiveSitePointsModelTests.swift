import Foundation
import Synchronization
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The map's two documents: the Commons one kept with its `ETag` and asked for once a launch, the
/// diver's read each time.
@MainActor
@Suite(.serialized)
struct DiveSitePointsModelTests {
  /// The `If-None-Match` each request for the Commons document carried, `-` for none.
  final class Tags: Sendable {
    private let sent = Mutex<[String]>([])
    func record(_ tag: String?) { sent.withLock { $0.append(tag ?? "-") } }
    var all: [String] { sent.withLock { $0 } }
  }

  private func world(_ tags: Tags) async throws -> FormWorld {
    let world = try FormWorld()
    let commons = try KitFixture.text("commons-dive-site-points")
    let mine = try KitFixture.text("dive-site-points")
    world.server.override { request, _ in
      switch request.route {
      case "GET commons/dive-sites/points":
        let tag = request.value(forHTTPHeaderField: "If-None-Match")
        tags.record(tag)
        if tag == #""b1.3f9a""# { return StubTransport.Response(status: 304) }
        return .json(commons, headers: ["ETag": #""b1.3f9a""#])
      case "GET dive-sites/points": return .json(mine)
      default: return nil
      }
    }
    try await world.session.loadAccount()
    return world
  }

  @Test func theCommonsDocumentIsAskedForOnceALaunchAndThenOnlyConfirmed() async throws {
    DiveSitePointsModel.forgetAsked()
    let tags = Tags()
    let world = try await world(tags)
    let first = DiveSitePointsModel(session: world.session)
    await first.load()
    #expect(first.commons?.points.count == 2)
    #expect(first.yours.map(\.name) == ["Canyon", "The Canyon"])
    await DiveSitePointsModel(session: world.session).load()
    #expect(tags.all == ["-"])

    DiveSitePointsModel.forgetAsked()
    let relaunched = DiveSitePointsModel(session: world.session)
    await relaunched.load()
    #expect(tags.all == ["-", #""b1.3f9a""#])
    #expect(relaunched.commons?.version == "3f9a1c0b7e2d4a65")
  }

  @Test func withNoRouteTheHeldPointsShow() async throws {
    DiveSitePointsModel.forgetAsked()
    let world = try await world(Tags())
    await DiveSitePointsModel(session: world.session).load()
    world.route.isRouteAvailable = false
    DiveSitePointsModel.forgetAsked()
    let offline = DiveSitePointsModel(session: world.session)
    await offline.load()
    #expect(offline.commons?.points.count == 2)
    #expect(offline.yours.count == 2)
  }

  @Test func aTouchedPointIsTheDiversFirstWithTheCreditItsSourceAsks() async throws {
    DiveSitePointsModel.forgetAsked()
    let world = try await world(Tags())
    let model = DiveSitePointsModel(session: world.session)
    await model.load()
    let saved = try #require(
      model.point(UUID(uuidString: "01a14b2e-0c3d-7a10-9f00-4b2b3c4d5e6f")!))
    #expect(saved.saved)
    #expect(saved.isCommons)
    #expect(saved.credit?.contains("OpenStreetMap") == true)
    let unsaved = try #require(
      model.point(UUID(uuidString: "01a14b2e-0c3d-7a10-9f00-4c2b3c4d5e6f")!))
    #expect(!unsaved.saved)
    #expect(unsaved.lookupItem.isCommons)
    #expect(unsaved.lookupItem.attribution == "[Wikidata, CC0](https://www.wikidata.org/)")
  }
}
