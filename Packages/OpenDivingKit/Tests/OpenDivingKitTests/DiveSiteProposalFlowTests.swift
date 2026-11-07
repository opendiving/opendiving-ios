import Foundation
import Synchronization
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The propose flow's steps over the server's answers, and what a send and a replace leave.
@MainActor
struct DiveSiteProposalFlowTests {
  private static let uuid = "01a0a521-28c5-7e34-a572-4d7324f5033b"
  private static let record = UUID(uuidString: "01a14b2e-0c3d-7a10-9f00-4b2b3c4d5e6f")!
  private static let matchesRoute = "GET dive-site/\(uuid)/commons-matches"
  private static let proposeRoute = "POST dive-site/\(uuid)/proposals"
  private static let replaceRoute = "POST dive-site/\(uuid)/replace"

  private func site(pinned: Bool = true) throws -> DiveSiteRead {
    var object =
      try JSONSerialization.jsonObject(with: Data(KitFixture.text("dive-site").utf8))
      as! [String: Any]
    if pinned {
      object["latitude"] = 28.5
      object["longitude"] = 34.5
    }
    return try APICoding.decoder().decode(
      DiveSiteRead.self, from: JSONSerialization.data(withJSONObject: object))
  }

  /// The record a replace answers.
  private func replaced() throws -> StubTransport.Response {
    .json(
      try KitFixture.text("dive-site")
        .replacingOccurrences(of: #""owner": "account""#, with: #""owner": "opendivingcommons""#)
        .replacingOccurrences(of: Self.uuid, with: APIClient.wire(Self.record)))
  }

  private func proposal() throws -> StubTransport.Response {
    let row = try KitFixture.decode(
      PaginatedListResponse<DiveSiteProposalRead>.self, "dive-site-proposals-page"
    ).data.first
    return .json(String(decoding: try APICoding.encoder().encode(row), as: UTF8.self), status: 201)
  }

  private func flow(
    _ routes: [String: StubTransport.Response], pinned: Bool = true
  ) throws -> (DiveSiteProposalFlow, StubTransport) {
    let transport = StubTransport(routes: routes)
    let flow = DiveSiteProposalFlow(
      session: Session.stub(transport: transport), site: try site(pinned: pinned))
    return (flow, transport)
  }

  @Test func anEmptyAnswerGoesStraightToTheReviewWithNothingToGoBackTo() async throws {
    let (flow, _) = try flow([Self.matchesRoute: .json("[]")])
    await flow.load()
    #expect(flow.step == .review)
    #expect(!flow.canGoBack)
  }

  @Test func matchesShowTheStepAndContinuingCanComeBack() async throws {
    var matches = try KitFixture.text("dive-site-commons-matches")
    matches = matches.replacingOccurrences(of: "\"identity\"", with: "\"within_20_m\"")
    let (flow, _) = try flow([Self.matchesRoute: .json(matches)])
    await flow.load()
    #expect(flow.step == .matches)
    #expect(flow.canContinue)
    flow.continueAsNewSite()
    #expect(flow.step == .review)
    #expect(flow.canGoBack)
    flow.back()
    #expect(flow.step == .matches)
  }

  @Test func anIdentityMatchOffersNoWayOn() async throws {
    let (flow, _) = try flow([
      Self.matchesRoute: .json(try KitFixture.text("dive-site-commons-matches"))
    ])
    await flow.load()
    #expect(flow.step == .matches)
    #expect(flow.hasIdentityMatch)
    #expect(!flow.canContinue)
  }

  @Test func aSiteWithNoPinStaysOnTheStepEvenWithNoMatches() async throws {
    let (flow, _) = try flow([Self.matchesRoute: .json("[]")], pinned: false)
    await flow.load()
    #expect(flow.step == .matches)
    #expect(!flow.canContinue)
    #expect(flow.needsPin)
  }

  @Test func aPinAddedThroughEditGoesOnToTheReview() async throws {
    let (flow, _) = try flow([Self.matchesRoute: .json("[]")], pinned: false)
    await flow.load()
    #expect(flow.needsPin)

    await flow.restart(with: try site())
    #expect(!flow.needsPin)
    #expect(flow.step == .review)
    #expect(!flow.canGoBack)
  }

  @Test func aFailedFetchShowsTheStepWithItsSentence() async throws {
    let (flow, _) = try flow([Self.matchesRoute: .json(#"{"detail":"Try later."}"#, status: 500)])
    await flow.load()
    #expect(flow.step == .matches)
    #expect(flow.loadError == "Try later.")
    #expect(!flow.canContinue)
    #expect(!flow.needsPin)
  }

  @Test func theSendCarriesTheAttestationAndNoMembers() async throws {
    let (flow, transport) = try flow([
      Self.matchesRoute: .json("[]"), Self.proposeRoute: try proposal(),
    ])
    await flow.load()
    flow.message = "Dived here for years."
    #expect(await !flow.send())
    #expect(transport.requests.allSatisfy { $0.route != Self.proposeRoute })

    flow.ticked = true
    #expect(await flow.send())
    let request = try #require(transport.requests.first { $0.route == Self.proposeRoute })
    let body = try JSONValue.parse(try #require(request.httpBody))
    #expect(body["attestation"] == .string(CommonsAttestations.newSite))
    #expect(body["message"] == .string("Dived here for years."))
    #expect(body["members"] == nil)
  }

  @Test func aRefusedSendStaysOnTheStepWithTheServersSentence() async throws {
    let (flow, _) = try flow([
      Self.matchesRoute: .json("[]"),
      Self.proposeRoute: .json(#"{"detail":"Too many today."}"#, status: 429),
    ])
    await flow.load()
    flow.message = "Hello"
    flow.ticked = true
    #expect(await !flow.send())
    #expect(flow.sendError == "Too many today.")
    #expect(flow.step == .review)
    #expect(flow.message == "Hello")
    #expect(flow.ticked)
    #expect(!flow.isSending)
  }

  @Test func aWordTooLongForTheReviewerIsNotSent() async throws {
    let (flow, transport) = try flow([Self.matchesRoute: .json("[]")])
    await flow.load()
    flow.message = String(repeating: "a", count: 2001)
    flow.ticked = true
    #expect(await !flow.send())
    #expect(flow.sendError != nil)
    #expect(transport.requests.allSatisfy { $0.route != Self.proposeRoute })
  }

  @Test func theFlowStartsAgainFromTheMatchesAfterAnEdit() async throws {
    let answers = Mutex(0)
    let matches = try KitFixture.text("dive-site-commons-matches")
    let route = Self.matchesRoute
    let transport = StubTransport { request in
      guard request.route == route else { return .json("{}", status: 404) }
      let first = answers.withLock { count in
        count += 1
        return count == 1
      }
      return .json(first ? "[]" : matches)
    }
    let flow = DiveSiteProposalFlow(session: Session.stub(transport: transport), site: try site())
    await flow.load()
    flow.ticked = true
    #expect(flow.step == .review)

    await flow.restart(with: try site())
    #expect(flow.step == .matches)
    #expect(!flow.ticked)
    #expect(flow.hasIdentityMatch)
  }

  @Test func aReplaceAnswersTheRecordAndNamesItOnTheWire() async throws {
    let (flow, transport) = try flow([
      Self.matchesRoute: .json("[]"),
      Self.replaceRoute: try replaced(),
    ])
    let record = await flow.replace(with: Self.record)
    #expect(flow.replacement.failure == nil)
    #expect(record?.isCommons == true)
    #expect(record?.uuid == Self.record)
    #expect(flow.replacement.replacing == nil)
    let request = try #require(transport.requests.first { $0.route == Self.replaceRoute })
    let body = try JSONValue.parse(try #require(request.httpBody))
    #expect(body["commons_site_uuid"] == .string(APIClient.wire(Self.record)))
  }

  @Test func aRefusedReplaceSaysWhyAndAnswersNothing() async throws {
    let (flow, _) = try flow([
      Self.replaceRoute: .json(#"{"detail":"That Commons site does not exist"}"#, status: 422)
    ])
    #expect(await flow.replace(with: Self.record) == nil)
    #expect(flow.replacement.failure == "That Commons site does not exist")
  }

  @Test func theSitesPageReplacesThroughItsModel() async throws {
    let transport = StubTransport(routes: [
      Self.replaceRoute: try replaced()
    ])
    let model = DiveSiteDetailModel(
      session: Session.stub(transport: transport), siteUUID: try site().uuid)
    #expect(await model.replace(with: Self.record)?.isCommons == true)
  }
}
